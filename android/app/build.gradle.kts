import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gitcs.davaindia.ff"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Never change this after the first release: updates only install
        // over an app with the same id and the same signing key.
        applicationId = "com.gitcs.davaindia.ff"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing comes from environment variables in CI, or from
    // android/key.properties on a developer machine. Without either, release
    // builds fall back to the debug key and must not be published.
    val keyProps = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    fun signing(name: String, env: String): String? = System.getenv(env) ?: keyProps.getProperty(name)
    val storePath = signing("storeFile", "ANDROID_KEYSTORE_PATH")

    signingConfigs {
        if (storePath != null) {
            create("release") {
                storeFile = file(storePath)
                storePassword = signing("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signing("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signing("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (storePath != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
