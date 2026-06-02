plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun firstNonBlank(vararg candidates: String?): String? {
    return candidates.firstOrNull { !it.isNullOrBlank() }
}

val releaseKeyAlias = firstNonBlank(
    project.findProperty("RIHLA_UPLOAD_KEY_ALIAS") as String?,
    System.getenv("RIHLA_UPLOAD_KEY_ALIAS"),
)
val releaseKeyPassword = firstNonBlank(
    project.findProperty("RIHLA_UPLOAD_KEY_PASSWORD") as String?,
    System.getenv("RIHLA_UPLOAD_KEY_PASSWORD"),
)
val releaseStorePassword = firstNonBlank(
    project.findProperty("RIHLA_UPLOAD_STORE_PASSWORD") as String?,
    System.getenv("RIHLA_UPLOAD_STORE_PASSWORD"),
)
val releaseStoreFilePath = firstNonBlank(
    project.findProperty("RIHLA_UPLOAD_STORE_FILE") as String?,
    System.getenv("RIHLA_UPLOAD_STORE_FILE"),
)
val hasReleaseSigning =
    !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseStoreFilePath.isNullOrBlank()
val allowDebugReleaseSigning =
    project.findProperty("allowDebugReleaseSigning") == "true" ||
        System.getenv("ORG_GRADLE_PROJECT_allowDebugReleaseSigning") == "true"
val isReleaseTaskRequested =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }

android {
    namespace = "com.rihla.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.14904198"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.rihla.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storePassword = releaseStorePassword
                storeFile = file(requireNotNull(releaseStoreFilePath))

                if (!requireNotNull(storeFile).exists()) {
                    throw GradleException(
                        "Release signing store file was not found at $releaseStoreFilePath.",
                    )
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                when {
                    hasReleaseSigning -> signingConfigs.getByName("release")
                    allowDebugReleaseSigning ||
                        !isReleaseTaskRequested -> signingConfigs.getByName("debug")
                    else -> throw GradleException(
                        "Release signing is not configured. Set RIHLA_UPLOAD_STORE_FILE, " +
                            "RIHLA_UPLOAD_STORE_PASSWORD, RIHLA_UPLOAD_KEY_ALIAS, and " +
                            "RIHLA_UPLOAD_KEY_PASSWORD via environment or Gradle properties, " +
                            "or pass -PallowDebugReleaseSigning=true for a local smoke build."
                    )
                }
        }
    }
}

flutter {
    source = "../.."
}
