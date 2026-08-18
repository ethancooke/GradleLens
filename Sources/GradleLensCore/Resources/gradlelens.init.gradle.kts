/*
 * GradleLens local capture — writes a JSON scan under build/reports/gradlelens/.
 * Install: copy to ~/.gradle/init.d/gradlelens.init.gradle.kts
 * Or: ./gradlew -I path/to/gradlelens.init.gradle.kts --profile <tasks>
 * Fully offline. Does not upload or contact the network.
 */
import org.gradle.api.services.BuildService
import org.gradle.api.services.BuildServiceParameters
import org.gradle.build.event.BuildEventsListenerRegistry
import org.gradle.tooling.events.FinishEvent
import org.gradle.tooling.events.OperationCompletionListener
import org.gradle.tooling.events.task.TaskFailureResult
import org.gradle.tooling.events.task.TaskFinishEvent
import org.gradle.tooling.events.task.TaskSkippedResult
import org.gradle.tooling.events.task.TaskSuccessResult
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import javax.inject.Inject

abstract class GradleLensCollector : BuildService<GradleLensCollector.Params>, OperationCompletionListener, AutoCloseable {
    interface Params : BuildServiceParameters {
        val rootDir: Property<String>
        val startedAtMillis: Property<Long>
        val requestedTasks: ListProperty<String>
        val excludedTasks: ListProperty<String>
        val gradleVersion: Property<String>
        val configurationCacheRequested: Property<Boolean>
    }

    data class TaskRow(
        val path: String,
        val durationMs: Long,
        val startMillis: Long,
        val result: String,
        val skipMessage: String?,
    )

    private val tasks = ConcurrentLinkedQueue<TaskRow>()
    private val sawFailure = AtomicBoolean(false)
    private val written = AtomicBoolean(false)
    private val rootOverride = AtomicReference<String?>(null)

    fun setRootDir(path: String) {
        rootOverride.set(path)
    }

    override fun onFinish(event: FinishEvent) {
        if (event !is TaskFinishEvent) return
        val result = event.result
        val duration = (result.endTime - result.startTime).coerceAtLeast(0L)
        val classified: String
        var skip: String? = null
        when (result) {
            is TaskFailureResult -> {
                classified = "failed"
                sawFailure.set(true)
            }
            is TaskSkippedResult -> {
                skip = result.skipMessage
                classified = classifySkip(skip)
            }
            is TaskSuccessResult -> {
                classified = when {
                    result.isFromCache -> "fromCache"
                    result.isUpToDate -> "upToDate"
                    else -> "executed"
                }
            }
            else -> classified = "unknown"
        }
        tasks.add(
            TaskRow(
                path = event.descriptor.taskPath,
                durationMs = duration,
                startMillis = result.startTime,
                result = classified,
                skipMessage = skip,
            ),
        )
    }

    @Suppress("UNUSED_PARAMETER")
    fun write(buildSucceeded: Boolean?) {
        if (!written.compareAndSet(false, true)) return
        val root = File(rootOverride.get() ?: parameters.rootDir.get())
        val outDir = File(root, "build/reports/gradlelens")
        if (!outDir.exists() && !outDir.mkdirs()) return

        val started = parameters.startedAtMillis.get()
        val finished = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val iso = DateTimeFormatter.ISO_OFFSET_DATE_TIME.withZone(zone)
        val fileStamp = DateTimeFormatter.ofPattern("yyyy-MM-dd-HH-mm-ss").withZone(zone)
        val out = File(outDir, "scan-${fileStamp.format(Instant.ofEpochMilli(started))}.json")

        val snapshot = tasks.toList().sortedBy { it.startMillis }
        val taskMs = snapshot.sumOf { it.durationMs }
        val succeeded = when (buildSucceeded) {
            null -> !sawFailure.get()
            else -> buildSucceeded && !sawFailure.get()
        }
        val outcome = if (succeeded) "succeeded" else "failed"
        val git = readGit(root)

        out.writeText(buildString {
            appendLine("{")
            appendLine("""  "schemaVersion": 1,""")
            appendLine("""  "source": "gradlelens-init",""")
            appendLine("""  "startedAt": ${jsonString(iso.format(Instant.ofEpochMilli(started)))},""")
            appendLine("""  "finishedAt": ${jsonString(iso.format(Instant.ofEpochMilli(finished)))},""")
            appendLine("""  "durationSeconds": ${seconds(finished - started)},""")
            appendLine("""  "outcome": ${jsonString(outcome)},""")
            appendLine("""  "requestedTasks": ${jsonStringList(parameters.requestedTasks.get())},""")
            appendLine("""  "excludedTasks": ${jsonStringList(parameters.excludedTasks.get())},""")
            appendLine("""  "gradleVersion": ${jsonString(parameters.gradleVersion.get())},""")
            appendLine("""  "rootDir": ${jsonString(root.absolutePath)},""")
            appendLine("""  "configurationCacheRequested": ${parameters.configurationCacheRequested.get()},""")
            append("  \"git\": ")
            if (git == null) {
                appendLine("null,")
            } else {
                appendLine("{")
                appendLine("""    "branch": ${jsonString(git.branch)},""")
                appendLine("""    "commit": ${jsonString(git.commit)},""")
                appendLine("""    "dirty": ${git.dirty}""")
                appendLine("  },")
            }
            appendLine("  \"phases\": {")
            appendLine("""    "total": ${seconds(finished - started)},""")
            appendLine("""    "taskExecution": ${seconds(taskMs)}""")
            appendLine("  },")
            appendLine("  \"tasks\": [")
            snapshot.forEachIndexed { index, task ->
                val offset = (task.startMillis - started).coerceAtLeast(0L)
                append("    {")
                append(""" "path": ${jsonString(task.path)},""")
                append(""" "durationSeconds": ${seconds(task.durationMs)},""")
                append(""" "startOffsetSeconds": ${seconds(offset)},""")
                append(""" "result": ${jsonString(task.result)}""")
                if (task.skipMessage != null) {
                    append(""", "skipMessage": ${jsonString(task.skipMessage)}""")
                }
                append(" }")
                if (index != snapshot.lastIndex) append(",")
                appendLine()
            }
            appendLine("  ]")
            appendLine("}")
        })
    }

    override fun close() {
        write(null)
    }

    private data class GitSnap(val branch: String?, val commit: String?, val dirty: Boolean)

    private fun readGit(root: File): GitSnap? {
        val inside = git(root, "rev-parse", "--is-inside-work-tree") ?: return null
        if (inside != "true") return null
        return GitSnap(
            branch = git(root, "rev-parse", "--abbrev-ref", "HEAD"),
            commit = git(root, "rev-parse", "HEAD"),
            dirty = !git(root, "status", "--porcelain").isNullOrBlank(),
        )
    }

    private fun git(root: File, vararg args: String): String? {
        return try {
            val builder = ProcessBuilder(listOf("git") + args.toList())
                .directory(root)
                .redirectErrorStream(true)
            builder.environment()["GIT_TERMINAL_PROMPT"] = "0"
            builder.environment()["GIT_OPTIONAL_LOCKS"] = "0"
            val process = builder.start()
            val output = process.inputStream.bufferedReader().readText().trim()
            if (process.waitFor() == 0) output else null
        } catch (_: Exception) {
            null
        }
    }

    private fun classifySkip(message: String?): String {
        val upper = message?.uppercase() ?: return "skipped"
        if (upper.contains("NO-SOURCE") || upper.contains("NO SOURCE")) return "skipped"
        if (upper.contains("UP-TO-DATE") || upper.contains("UP TO DATE")) return "upToDate"
        if (upper.contains("FROM-CACHE") || upper.contains("FROM_CACHE")) return "fromCache"
        return "skipped"
    }

    private fun seconds(ms: Long): String = "%.3f".format(ms / 1000.0)

    private fun jsonString(value: String?): String {
        if (value == null) return "null"
        val escaped = buildString {
            for (ch in value) {
                when (ch) {
                    '\\' -> append("\\\\")
                    '"' -> append("\\\"")
                    '\n' -> append("\\n")
                    '\r' -> append("\\r")
                    '\t' -> append("\\t")
                    else -> if (ch.code < 32) append("\\u%04x".format(ch.code)) else append(ch)
                }
            }
        }
        return "\"$escaped\""
    }

    private fun jsonStringList(values: List<String>): String =
        values.joinToString(prefix = "[", postfix = "]") { jsonString(it) }
}

abstract class GradleLensPlugin @Inject constructor(
    private val registry: BuildEventsListenerRegistry,
) : Plugin<Gradle> {
    override fun apply(gradle: Gradle) {
        val started = System.currentTimeMillis()
        val collector = gradle.sharedServices.registerIfAbsent("gradleLensCollector", GradleLensCollector::class.java) {
            parameters.rootDir.set(gradle.startParameter.currentDir.absolutePath)
            parameters.startedAtMillis.set(started)
            parameters.requestedTasks.set(gradle.startParameter.taskNames)
            parameters.excludedTasks.set(gradle.startParameter.excludedTaskNames.toList())
            parameters.gradleVersion.set(gradle.gradleVersion)
            parameters.configurationCacheRequested.set(configurationCacheRequested(gradle))
        }
        registry.onTaskCompletion(collector)
    }

    private fun configurationCacheRequested(gradle: Gradle): Boolean {
        val start = gradle.startParameter
        return try {
            val method = start.javaClass.methods.firstOrNull { it.name == "isConfigurationCacheRequested" }
            if (method != null) return method.invoke(start) as? Boolean ?: false
            val cc = start.javaClass.methods.firstOrNull { it.name == "getConfigurationCache" }?.invoke(start)
            when (cc) {
                is Boolean -> cc
                null -> false
                else -> (cc.javaClass.methods.firstOrNull { it.name == "get" }?.invoke(cc) as? Boolean) ?: false
            }
        } catch (_: Exception) {
            false
        }
    }
}

apply<GradleLensPlugin>()
