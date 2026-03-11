plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.frohlfing.privault.privault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "de.frohlfing.privault.privault"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Füge deine eigene Signaturkonfiguration für den Release-Build hinzu.
            //
            // Aktuell wird mit den Debug-Schlüsseln signiert, damit `flutter run --release` funktioniert.
            // Google akzeptiert aber keine Debug-Signatur. Das musst daher du tun, wenn du die App veröffentlichen
            // willst:
            // 1. Eigenen "Upload Key" erstellen (eine .jks oder .keystore Datei).
            // 2. Zugangsdaten sicher speichern (am besten in einer key.properties Datei).
            // 3. Diesen Code-Block in der `build.gradle.kts` anpassen, damit er auf deinen echten Schlüssel verweist,
            //    statt auf `signingConfigs.getByName("debug")`.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
