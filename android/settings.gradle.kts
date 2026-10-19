// Clear conflicting ANDROID_PREFS_ROOT environment variable if ANDROID_USER_HOME is also present
try {
    val processEnvironment = Class.forName("java.lang.ProcessEnvironment")
    val fields = arrayOf("theEnvironment", "theUnmodifiableEnvironment", "theCaseInsensitiveEnvironment")
    for (fieldName in fields) {
        try {
            val field = processEnvironment.getDeclaredField(fieldName)
            field.isAccessible = true
            @Suppress("UNCHECKED_CAST")
            val map = field.get(null) as? MutableMap<String, String>
            map?.keys?.removeAll { it.equals("ANDROID_PREFS_ROOT", ignoreCase = true) }
        } catch (_: Throwable) {}
    }
    System.clearProperty("ANDROID_PREFS_ROOT")
} catch (_: Throwable) {
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
