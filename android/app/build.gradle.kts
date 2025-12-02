plugins {
id("com.android.application")
id("kotlin-android")
// The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
id("dev.flutter.flutter-gradle-plugin")
}

android {
namespace = "com.holox.ailand_pos"
compileSdk = 36 // 升级以满足插件要求（向后兼容）
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
applicationId = "com.holox.ailand_pos"
// You can update the following values to match your application needs.
// For more information, see: https://flutter.dev/to/review-gradle-config.
minSdk = 28 // Android 9 (Pie) - 兼容要求
targetSdk = 36
versionCode = flutter.versionCode
versionName = flutter.versionName

// 添加NDK支持
ndk {
abiFilters.add("arm64-v8a")
abiFilters.add("armeabi-v7a")
}
}

buildTypes {
release {
// TODO: Add your own signing config for the release build.
// Signing with the debug keys for now, so `flutter run --release` works.
signingConfig = signingConfigs.getByName("debug")

// 禁用混淆以避免第三方SDK兼容性问题
isMinifyEnabled = false
isShrinkResources = false
}
}
}

flutter {
source = "../.."
}

dependencies {
// Sunmi Customer API SDK
implementation(files("libs/SUNMI_CUSTOMER_API_v1.0.62_release.aar"))

// MW Card Reader SDK (需要手动添加这些JAR文件到libs目录)
// 下载地址见文档: MW读卡器Flutter接入文档.md
implementation(files("libs/mwcard-6.0.0.19.jar"))
implementation(files("libs/decodewlt-1.0.0.1.jar"))
}
