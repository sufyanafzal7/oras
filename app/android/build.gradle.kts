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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileSdkVersion(36)
            }
        }
    }
}
gradle.projectsEvaluated {
    subprojects {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
        tasks.withType(JavaCompile::class.java).configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}
gradle.projectsEvaluated {
    subprojects {
        tasks.matching { it.name == "compileReleaseJavaWithJavac" }.configureEach {
            doFirst {
                val jc = this as JavaCompile
                println("=====================================================")
                println("DIAGNOSTIC — module: ${project.name}")
                println("  compileSdk (from android extension, if found): " +
                        (project.extensions.findByType<com.android.build.gradle.BaseExtension>()
                            ?.compileSdkVersion ?: "NOT FOUND"))
                println("  bootstrapClasspath: " +
                        (jc.options.bootstrapClasspath?.files?.joinToString() ?: "NONE SET"))
                println("  classpath entry count: ${jc.classpath.files.size}")
                jc.classpath.files.take(8).forEach { println("    - $it") }
                println("=====================================================")
            }
        }
    }
}