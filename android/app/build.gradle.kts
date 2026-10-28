import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// İmza anahtarının bilgileri android/key.properties dosyasından okunur.
// Bu dosya depoda yok; GitHub Actions derlerken gizli bilgilerden (secrets) oluşturur.
// Hep aynı anahtarla imzalandığı için yeni sürüm eskisinin üstüne veriler silinmeden kurulur.
val anahtarBilgisi = Properties()
val anahtarDosyasi = rootProject.file("key.properties")
if (anahtarDosyasi.exists()) {
    FileInputStream(anahtarDosyasi).use { anahtarBilgisi.load(it) }
}

android {
    namespace = "com.seyfettin.ezan_vakitlerim"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Bildirim eklentisi yeni Java tarih kütüphanesini istiyor
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.seyfettin.ezan_vakitlerim"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (anahtarDosyasi.exists()) {
                keyAlias = anahtarBilgisi["keyAlias"] as String
                keyPassword = anahtarBilgisi["keyPassword"] as String
                storeFile = file(anahtarBilgisi["storeFile"] as String)
                storePassword = anahtarBilgisi["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Anahtar varsa kendi anahtarımızla, yoksa (kendi bilgisayarında denerken) debug anahtarıyla imzala
            signingConfig = if (anahtarDosyasi.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
