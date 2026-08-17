pluginManagement {
    includeBuild("build-logic")
}

rootProject.name = "gradleCacheLearn"
include("app", "list", "utilities")
include(":feature:home")
includeBuild("../convention-plugins")
