import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration

    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key 설정
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Dart Define 설정
val dartDefines = emptyList<String>()

fun dartDefineValue(key: String): String? = null

android {
    namespace = "com.han.RunePuzzleTactics"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Kotlin JVM 설정
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.han.RunePuzzleTactics"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["admobAppId"] =
            dartDefineValue("ADMOB_APP_ID")
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    // Release signing 설정
    signingConfigs {
        create("release") {
            val hasKeyProps = keystoreProperties.isNotEmpty()

            if (hasKeyProps) {
                keyAlias =
                    keystoreProperties.getProperty("keyAlias") ?: ""

                keyPassword =
                    keystoreProperties.getProperty("keyPassword") ?: ""

                storePassword =
                    keystoreProperties.getProperty("storePassword") ?: ""

                val storePath =
                    keystoreProperties.getProperty("storeFile")

                if (!storePath.isNullOrBlank()) {
                    val keyFile = file(storePath)

                    storeFile =
                        if (keyFile.isAbsolute) {
                            keyFile
                        } else {
                            rootProject.file(storePath)
                        }
                }
            }
        }
    }

    buildTypes {
        release {
            val hasKeyProps = keystoreProperties.isNotEmpty()

            signingConfig =
                if (hasKeyProps) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}