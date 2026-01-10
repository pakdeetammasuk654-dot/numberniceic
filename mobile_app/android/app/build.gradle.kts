plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.taya.numberniceic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.taya.numberniceic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // LINE Login Scheme
        manifestPlaceholders["lineChannelScheme"] = "line3rdp.com.taya.numberniceic"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

tasks.register("printSHA1") {
    doLast {
        println("🔑 TEMPORARY SHA-1 PRINTER 🔑")
        val keystoreFile = File(System.getProperty("user.home") + "/.android/debug.keystore")
        if (keystoreFile.exists()) {
             println("Debug keystore found at: ${keystoreFile.absolutePath}")
             // Note: Executing keytool from Gradle is tricky without knowing path.
             // But we can try to find it or print instructions.
             println("To get SHA-1, please run this in your terminal:")
             println("keytool -list -v -keystore ${keystoreFile.absolutePath} -alias androiddebugkey -storepass android -keypass android")
        } else {
             println("Debug keystore NOT found at default location.")
        }
    }
}
