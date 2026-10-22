plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 应用包名：必须与 Firebase 控制台中登记的 Android 包名一致
    namespace = "com.example.couple_meal_log"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.couple_meal_log"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 默认使用 debug 签名，便于直接 flutter build apk 安装测试；
            // 正式发布时请按 README 的「签名说明」配置自己的 keystore。
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Firebase 配置：把 Firebase 控制台下载的 google-services.json 放到 android/app/ 目录。
// 存在该文件时自动应用 com.google.gms.google-services 插件（插件版本在 settings.gradle.kts 中声明）。
val googleServicesJson = file("google-services.json")
if (googleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
