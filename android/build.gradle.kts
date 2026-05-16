allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Suppress obsolete -source/-target 8 warnings during Java compilation
// Recommended: run Gradle with JDK 17 by setting JAVA_HOME to a Java 17 installation.
subprojects {
    tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-options"))
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

plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  id("com.google.gms.google-services") version "4.4.4" apply false

}
