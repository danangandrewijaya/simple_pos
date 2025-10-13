import java.util.Properties
import java.io.FileInputStream
import java.io.InputStreamReader

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.kamaya.simplepos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "dev.kamaya.simplepos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    // Disable lint on release to avoid Windows file lock issues during CI/local builds
    lint {
        checkReleaseBuilds = false
        abortOnError = false
        warningsAsErrors = false
    }

    // Load keystore properties for release signing
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")

    var propStoreFile: String? = null
    var propStorePassword: String? = null
    var propKeyAlias: String? = null
    var propKeyPassword: String? = null

    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { fis ->
            InputStreamReader(fis, Charsets.UTF_8).use { reader ->
                keystoreProperties.load(reader)
            }
        }

        fun readProp(name: String): String? {
            // Handle potential UTF-8 BOM prefix on the first key (\uFEFF)
            val v = keystoreProperties.getProperty(name)
                ?: keystoreProperties.getProperty("\uFEFF$name")
            return v?.trim()?.ifBlank { null }
        }

        propStoreFile = readProp("storeFile")
        propStorePassword = readProp("storePassword")
        propKeyAlias = readProp("keyAlias")
        propKeyPassword = readProp("keyPassword")

        println("[Gradle] Loaded key.properties from ${keystorePropertiesFile.absolutePath} size=${keystoreProperties.size}")
        println("[Gradle] storeFile=${propStoreFile}, keyAlias=${propKeyAlias}, storePassword.len=${propStorePassword?.length}, keyPassword.len=${propKeyPassword?.length}")
    } else {
        println("[Gradle] key.properties not found at ${keystorePropertiesFile.absolutePath}")
    }

    signingConfigs {
        create("release") {
            if (propStoreFile != null && propStorePassword != null && propKeyAlias != null && propKeyPassword != null) {
                val sf = file(propStoreFile!!)
                if (!sf.exists()) {
                    throw GradleException("Keystore file not found: ${sf.absolutePath}")
                }
                storeFile = sf
                storePassword = propStorePassword
                keyAlias = propKeyAlias
                keyPassword = propKeyPassword
                // For clarity when debugging; do not print secrets
                println("[Gradle] Applied release signingConfig: file=${sf.absolutePath}, keyAlias=${keyAlias}")
            } else {
                println("[Gradle][WARN] key.properties is incomplete; release signing will NOT be applied")
            }
        }
    }

    println("[Gradle] signingConfigs available: ${signingConfigs.names}")

    buildTypes {
        release {
            // Always prefer explicit release signing config; fallback only if it's incomplete
            val releaseCfg = signingConfigs.findByName("release")
            if (releaseCfg != null && releaseCfg.storeFile != null && !releaseCfg.keyAlias.isNullOrBlank()) {
                signingConfig = releaseCfg
                println("[Gradle] Using signingConfig 'release'")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                println("[Gradle][WARN] Falling back to 'debug' signingConfig")
            }
        }
    }
}

flutter {
    source = "../.."
}
