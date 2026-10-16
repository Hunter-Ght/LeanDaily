plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.leandaily"
    compileSdk = flutter.compileSdkVersion
    // 使用 NDK 的 llvm-strip 去掉调试信息，保留 Android 加载器必需的 ELF 区段表。
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.leandaily"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("personal") {
            val store = System.getenv("LEANDAILY_STORE_FILE")
            if (store != null) {
                storeFile = file(store)
                storePassword = System.getenv("LEANDAILY_SIGNING_PASSWORD")
                keyAlias = System.getenv("LEANDAILY_KEY_ALIAS") ?: "leandaily"
                keyPassword = System.getenv("LEANDAILY_SIGNING_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // 不要混淆/裁剪：libflutter.so 按原类名回调 FlutterJNI，被 R8 改名后引擎起不来（启动图标一直不消失）。
            isMinifyEnabled = false
            isShrinkResources = false
            // 与 1.x 同一把签名，才能直接覆盖安装；没有环境变量时回退到调试签名，仅用于本机试跑。
            signingConfig = if (System.getenv("LEANDAILY_STORE_FILE") != null) signingConfigs.getByName("personal") else signingConfigs.getByName("debug")
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
