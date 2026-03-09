allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

fun Project.configureMissingAndroidNamespace() {
    plugins.withId("com.android.library") {
        val androidExtension = extensions.findByName("android") ?: return@withId
        val namespaceGetter = androidExtension.javaClass.methods.firstOrNull {
            it.name == "getNamespace" && it.parameterCount == 0
        }
        val namespaceSetter = androidExtension.javaClass.methods.firstOrNull {
            it.name == "setNamespace" && it.parameterCount == 1
        } ?: return@withId

        val currentNamespace = namespaceGetter?.invoke(androidExtension) as? String
        if (!currentNamespace.isNullOrBlank()) {
            return@withId
        }

        val fallbackNamespace = group.toString()
            .takeIf { it.isNotBlank() && it != "unspecified" }
            ?: "com.example.${name.replace('-', '_')}"

        namespaceSetter.invoke(androidExtension, fallbackNamespace)
    }
}

fun Project.configureCameraXCompatibility() {
    if (name != "camera_android_camerax") {
        return
    }

    plugins.withId("com.android.library") {
        dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.3.0")
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
    configureMissingAndroidNamespace()
    configureCameraXCompatibility()
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
