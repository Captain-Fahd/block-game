pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")

// NixOS: Flutter SDK plugins (e.g. integration_test) live in the read-only
// Nix store, and Gradle 9 refuses project directories it can't write to.
// Point any such plugin project at a writable copy under build/. No-op on
// normal (writable) SDK installs. See docs/decisions/001-nixos-aapt2.md.
gradle.settingsEvaluated {
    val copies = file("../build/nix-sdk-plugins")
    rootProject.children.forEach { p ->
        val dir = p.projectDir
        if (dir.isDirectory && !java.nio.file.Files.isWritable(dir.toPath())) {
            val copy = copies.resolve(p.name)
            if (!copy.isDirectory) {
                dir.copyRecursively(copy, overwrite = true)
                copy.walkTopDown().forEach { it.setWritable(true, true) }
            }
            p.projectDir = copy
        }
    }
}
