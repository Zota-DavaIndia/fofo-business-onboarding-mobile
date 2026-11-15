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

    // Needed for the Firebase resources in defaultConfig (resValue is off by default in AGP 9).
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        // Never change this after the first release: updates only install
        // over an app with the same id and the same signing key.
        applicationId = "com.gitcs.davaindia.ff"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Google Maps key: MAPS_API_KEY in CI, or MAPS_API_KEY in local.properties. Empty leaves maps blank.
        val localProps = Properties().apply {
            val f = rootProject.file("local.properties")
            if (f.exists()) f.inputStream().use { load(it) }
        }
        manifestPlaceholders["mapsApiKey"] = System.getenv("MAPS_API_KEY") ?: localProps.getProperty("MAPS_API_KEY") ?: ""

        // Firebase for pushes that arrive while the app isn't running. These are the resources the Google
        // Services plugin writes from google-services.json; with them Android sets up Firebase when a push
        // wakes the app, so the notification still shows. Same FIREBASE_* values as the Dart side, from the
        // environment in CI or local.properties; without them pushes only reach a running app.
        fun firebase(name: String): String = System.getenv(name) ?: localProps.getProperty(name) ?: ""
        if (firebase("FIREBASE_ANDROID_APP_ID").isNotEmpty()) {
            resValue("string", "google_app_id", firebase("FIREBASE_ANDROID_APP_ID"))
            resValue("string", "gcm_defaultSenderId", firebase("FIREBASE_SENDER_ID"))
            resValue("string", "google_api_key", firebase("FIREBASE_API_KEY"))
            resValue("string", "project_id", firebase("FIREBASE_PROJECT_ID"))
        }
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

    // Release lint crashes inside lint itself on image_picker_android's Java sources
    // (NoSuchMethodError in JavaDocParser). `./gradlew lint` still works.
    lint {
        checkReleaseBuilds = false
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

dependencies {
    // FileProvider, for handing downloaded updates to the system installer
    implementation("androidx.core:core-ktx:1.13.1")
}
