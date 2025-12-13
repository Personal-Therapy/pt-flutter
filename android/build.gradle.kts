allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    if (name == "flutter_wear_os_connectivity") {
        val configureNamespace = {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                // [수정됨] mjohnsullivan -> sstonn 으로 변경
                namespace = "com.sstonn.flutter_wear_os_connectivity"
            }
        }

        if (state.executed) {
            configureNamespace()
        } else {
            afterEvaluate { configureNamespace() }
        }
    }
}