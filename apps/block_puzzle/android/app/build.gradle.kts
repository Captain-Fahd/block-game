plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// AdMob app id for the manifest. Debug/profile builds always use Google's
// sample id; release builds use ADMOB_APP_ID from
// --dart-define-from-file=env/prod.json when it's set (CLAUDE.md: real ids
// only in release). Flutter passes dart-defines to Gradle base64-encoded.
val sampleAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { encoded ->
            runCatching { String(java.util.Base64.getDecoder().decode(encoded)) }.getOrNull()
        }
        ?.mapNotNull { kv ->
            val i = kv.indexOf('=')
            if (i > 0) kv.substring(0, i) to kv.substring(i + 1) else null
        }
        ?.toMap()
        ?: emptyMap()
val releaseAdMobAppId = dartDefines["ADMOB_APP_ID"]?.takeIf { it.isNotBlank() } ?: sampleAdMobAppId

android {
    namespace = "com.omarfahd.blockpuzzle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Interim id; becomes com.omarfahd.<name> once the name is picked (P2.0).
        applicationId = "com.omarfahd.blockpuzzle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = sampleAdMobAppId
    }

    buildTypes {
        release {
            manifestPlaceholders["admobAppId"] = releaseAdMobAppId
            // TODO(P7.4): upload-key signing config from key.properties.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
