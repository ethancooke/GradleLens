import Foundation
import Testing

@testable import GradleLensCore

@Suite("ProjectStructureReader")
struct ProjectStructureReaderTests {
    @Test("Parses Kotlin DSL settings")
    func kotlinSettings() throws {
        let source = try String(contentsOf: fixtureURL("settings", extension: "gradle.kts"), encoding: .utf8)
        #expect(ProjectStructureReader.rootProjectName(in: source) == "gradleCacheLearn")
        #expect(
            ProjectStructureReader.includedModulePaths(in: source) == [
                ":app", ":list", ":utilities", ":feature:home",
            ]
        )
        #expect(
            ProjectStructureReader.includedBuilds(in: source) == [
                "build-logic", "../convention-plugins",
            ]
        )
        #expect(ProjectStructureReader.directory(forModulePath: ":feature:home") == "feature/home")
    }

    @Test("Parses Groovy settings")
    func groovySettings() throws {
        let source = try String(contentsOf: fixtureURL("settings", extension: "gradle"), encoding: .utf8)
        #expect(ProjectStructureReader.rootProjectName(in: source) == "legacy-app")
        #expect(
            ProjectStructureReader.includedModulePaths(in: source) == [
                ":app", ":lib", ":data", ":feature:home",
            ]
        )
        #expect(ProjectStructureReader.includedBuilds(in: source) == ["build-logic"])
    }

    @Test("Ignores comments when reading include()")
    func comments() {
        let source = """
            // include("nope")
            rootProject.name = "demo"
            include("app")
            /* include("also-no") */
            """
        #expect(ProjectStructureReader.includedModulePaths(in: source) == [":app"])
    }

    @Test("Infers tasks from register() and plugins")
    func inferredTasks() {
        let source = """
            plugins {
                id("org.jetbrains.kotlin.jvm")
                id("java-library")
            }
            tasks.register("customReport") {}
            task hello
            """
        let tasks = ProjectStructureReader.inferredTasks(inSource: source)
        #expect(tasks.contains("customReport"))
        #expect(tasks.contains("hello"))
        #expect(tasks.contains("compileKotlin"))
        #expect(tasks.contains("compileJava"))
    }
}

@Suite("GradleProjectDetector")
struct GradleProjectDetectorTests {
    @Test("Reads the wrapper version from distributionUrl")
    func wrapperVersion() {
        let properties = """
            distributionBase=GRADLE_USER_HOME
            distributionPath=wrapper/dists
            distributionUrl=https\\://services.gradle.org/distributions/gradle-8.14.3-bin.zip
            networkTimeout=10000
            """
        #expect(GradleProjectDetector.gradleVersion(fromWrapperProperties: properties) == "8.14.3")
    }

    @Test("Detects a Gradle project from settings or build files")
    func detection() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-detect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(GradleProjectDetector.isGradleProject(at: root) == false)
        try "rootProject.name = \"demo\"".write(
            to: root.appendingPathComponent("settings.gradle.kts"),
            atomically: true,
            encoding: .utf8
        )
        #expect(GradleProjectDetector.isGradleProject(at: root))
        #expect(GradleProjectDetector.displayName(at: root) == "demo")
    }
}
