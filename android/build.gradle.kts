import com.android.build.gradle.LibraryExtension

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

subprojects {
    plugins.withId("com.android.library") {
        val namespaceMap = mapOf(
            "flutter_baidu_mapapi_map" to "com.baidu.bmfmap",
            "flutter_baidu_mapapi_base" to "com.baidu.mapapi.base",
            "flutter_bmflocation" to "com.baidu.flutter_bmflocation",
        )
        val fixedNamespace = namespaceMap[name] ?: return@withId
        extensions.configure<LibraryExtension>("android") {
            namespace = fixedNamespace
        }
        // AGP 8+: library AndroidManifest.xml must not define package when namespace is used.
        val sanitizePluginManifest = tasks.register("sanitize${name}ManifestPackage") {
            doLast {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (!manifestFile.exists()) return@doLast
                val original = manifestFile.readText()
                val sanitized = original.replace(
                    Regex("""\s+package="[^"]+""""),
                    "",
                )
                if (sanitized != original) {
                    manifestFile.writeText(sanitized)
                }
            }
        }
        tasks.matching { it.name == "preBuild" }.configureEach {
            dependsOn(sanitizePluginManifest)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
