plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mirrorly.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring is required by `flutter_local_notifications`
        // (and any plugin targeting java.time on pre-API-26 devices). Without
        // this, `flutter build apk --release` fails on checkReleaseAarMetadata:
        //   ":flutter_local_notifications requires core library desugaring".
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.mirrorly.app"
        // ML Kit Face Mesh requires Android 6.0+ (API 23). Below that the
        // detector loads but silently returns empty meshes — which was our
        // exact Android silent-failure bug.
        // Source: https://developers.google.com/ml-kit/vision/face-mesh-detection/android
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ML Kit does NOT support 32-bit ARM (armv7). Restrict to the ABIs
        // that ship working ML Kit native libraries — arm64 covers modern
        // phones, x86_64 covers emulators.
        // Source: https://developers.google.com/ml-kit/known-issues
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            // Signing with debug keys so `flutter run --release` works. Swap
            // to real keys before shipping.
            signingConfig = signingConfigs.getByName("debug")

            // ML Kit classes are reached via reflection inside the detector
            // SDK. Without keep rules, R8 silently strips them and the
            // detector emits empty lists. See proguard-rules.pro.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for `isCoreLibraryDesugaringEnabled = true` above.
    // Version 2.0.4+ is the one flutter_local_notifications documents.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
