import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        load(keystorePropertiesFile.inputStream())
    }
}

android {
    namespace = "app.echoloop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.echoloop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 只打包 arm64
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    packaging {
        jniLibs {
            // 强制排除非 arm64 的 so，防止 Flutter 插件绕过 abiFilters
            excludes += listOf("lib/x86_64/**", "lib/armeabi-v7a/**", "lib/x86/**")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    buildTypes {
        release {}
    }

    // 与 iOS 的 dev / prod scheme 保持一致：
    // dev  -> app.echoloop.dev  / "Echo Loop Dev"
    // prod -> app.echoloop      / "Echo Loop"
    // 这里按 flavor 固定签名：dev 使用 debug 证书，prod 使用 release 证书。
    // 这样同一个 package 的 debug / release 会保持同一把签名，便于 Google 登录配置。
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Echo Loop Dev")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Echo Loop")
        }
    }
}

androidComponents {
    onVariants(selector().all()) { variant ->
        if (variant.name.startsWith("prod")) {
            variant.signingConfig.setConfig(
                android.signingConfigs.getByName("release"),
            )
        } else if (variant.name.startsWith("dev")) {
            variant.signingConfig.setConfig(
                android.signingConfigs.getByName("debug"),
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-base:18.9.0")
    testImplementation("junit:junit:4.13.2")
    // flutter-plugin-loader 将 integration_test (dev_dependency) 只注入 debugImplementation，
    // 但 GeneratedPluginRegistrant.java 在所有构建变体中均引用该类，导致 release 编译失败。
    // 此处补充 releaseImplementation 使编译通过；try-catch 保证运行时初始化失败不影响 app。
    releaseImplementation(project(":integration_test"))
}
