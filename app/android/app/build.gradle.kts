import com.android.build.gradle.AppExtension
import com.android.build.gradle.api.ApkVariantOutput
import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/** pubspec build-number（写入 android/local.properties 的 flutter.versionCode） */
fun readFlutterVersionCodeFromLocalProperties(project: org.gradle.api.Project): Int {
    val props = Properties()
    val localProperties = project.rootProject.file("local.properties")
    if (!localProperties.isFile) {
        return 1
    }
    localProperties.inputStream().use { props.load(it) }
    return props.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
}

// 必须在 Flutter 插件写入 ABI*1000+buildNumber 之前占用 versionCodeOverride（只能赋值一次）
plugins.withId("com.android.application") {
    val pubVersionCode = readFlutterVersionCodeFromLocalProperties(project)
    extensions.configure<AppExtension>("android") {
        applicationVariants.configureEach {
            outputs.configureEach {
                @Suppress("DEPRECATION")
                (this as ApkVariantOutput).versionCodeOverride = pubVersionCode
            }
        }
    }
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.ultrasend.app"
    compileSdk = flutter.compileSdkVersion
    // Google Play 16 KB page size: NDK r28+ aligns native libs to 16 KB.
    ndkVersion = "28.2.13676358"

    compileOptions {
        // 与 device_info_plus 12.x 等插件的 Android 模块一致（Kotlin jvmTarget 17）
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 需要 core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { path -> file(path) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.ultrasend.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "distribution"
    productFlavors {
        create("direct") {
            dimension = "distribution"
        }
        create("play") {
            dimension = "distribution"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // abiFilters 与 --split-per-abi 冲突，由 Flutter 按 target-platform 配置 splits
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.documentfile:documentfile:1.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// `flutter build apk` / `flutter run` without `--flavor` expects `app-<mode>.apk` under
// `outputs/flutter-apk/`, but product flavors emit `app-direct-<mode>.apk` and
// `app-play-<mode>.apk`. Default channel for this repo is `direct` (see
// `scripts/build-android.sh`); mirror that so plain Flutter CLI invocations succeed.
// Also emit versioned copies (pubspec x.y.z+b → x.y.z.b), e.g.
// `app-direct-arm64-v8a-release-1.1.7.17.apk` and branded arm64 split APKs.
afterEvaluate {
    val versionLabel = "${flutter.versionName}.${flutter.versionCode}"
    val releaseAbi = "arm64-v8a"

    fun postProcessFlutterApks(mode: String, flavor: String) {
        val dir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        if (!dir.isDirectory) return

        // Flutter 3.x: app-<abi>-<flavor>-<mode>.apk；旧顺序 app-<flavor>-<abi>-<mode>.apk
        val splitApk = listOf(
            File(dir, "app-$releaseAbi-$flavor-$mode.apk"),
            File(dir, "app-$flavor-$releaseAbi-$mode.apk"),
        ).firstOrNull { it.isFile }

        if (splitApk != null) {
            splitApk.copyTo(
                File(dir, "app-$releaseAbi-$flavor-$mode-$versionLabel.apk"),
                overwrite = true,
            )
            splitApk.copyTo(
                File(dir, "app-$flavor-$releaseAbi-$mode-$versionLabel.apk"),
                overwrite = true,
            )
            if (mode == "release") {
                splitApk.copyTo(
                    File(dir, "Shrimpsend-android-$flavor-$releaseAbi-$versionLabel.apk"),
                    overwrite = true,
                )
                // 删除 universal / 其它 ABI 的 release APK，避免 package 脚本误复制大体积总包
                dir.listFiles()
                    ?.filter { file ->
                        file.isFile &&
                            file.extension == "apk" &&
                            file.name.contains("-$flavor-") &&
                            file.name.contains("-$mode") &&
                            !file.name.contains(releaseAbi) &&
                            file.absolutePath != splitApk.absolutePath
                    }
                    ?.forEach { it.delete() }
                File(dir, "app-$flavor-$mode.apk").takeIf { it.isFile }?.delete()
                File(dir, "app-$flavor-$mode-$versionLabel.apk").takeIf { it.isFile }?.delete()
                File(dir, "Shrimpsend-android-$flavor-$versionLabel.apk").takeIf { it.isFile }?.delete()
            }
            if (flavor == "direct" && mode == "debug") {
                splitApk.copyTo(File(dir, "app-$mode.apk"), overwrite = true)
            }
            return
        }

        // 非 split 构建（本地调试等）仍做通用命名，避免破坏 flutter run
        val flavorMode = "-$flavor-$mode"
        dir.listFiles()
            ?.filter { file ->
                file.isFile &&
                    file.extension == "apk" &&
                    file.name.contains(flavorMode) &&
                    !file.name.contains(versionLabel)
            }
            ?.forEach { apk ->
                val base = apk.name.removeSuffix(".apk")
                apk.copyTo(File(dir, "$base-$versionLabel.apk"), overwrite = true)
            }

        val branded = File(dir, "app-$flavor-$mode.apk")
        if (branded.isFile) {
            if (flavor == "direct") {
                branded.copyTo(File(dir, "app-$mode.apk"), overwrite = true)
                branded.copyTo(File(dir, "app-$mode-$versionLabel.apk"), overwrite = true)
            }
            if (mode == "release") {
                branded.copyTo(
                    File(dir, "Shrimpsend-android-$flavor-$versionLabel.apk"),
                    overwrite = true,
                )
            }
        }
    }

    fun postProcessFlutterBundles(mode: String, flavor: String) {
        if (mode != "release") return
        val capMode = mode.replaceFirstChar { it.uppercase() }
        val dir = layout.buildDirectory.dir("outputs/bundle/${flavor}$capMode").get().asFile
        if (!dir.isDirectory) return

        val flavorMode = "-$flavor-$mode"
        dir.listFiles()
            ?.filter { file ->
                file.isFile &&
                    file.extension == "aab" &&
                    file.name.contains(flavorMode) &&
                    !file.name.contains(versionLabel)
            }
            ?.forEach { aab ->
                val base = aab.name.removeSuffix(".aab")
                aab.copyTo(File(dir, "$base-$versionLabel.aab"), overwrite = true)
            }

        val branded = File(dir, "app-$flavor-$mode.aab")
        if (branded.isFile) {
            branded.copyTo(File(dir, "app-$flavor-$mode-$versionLabel.aab"), overwrite = true)
            branded.copyTo(
                File(dir, "Shrimpsend-android-$flavor-$versionLabel.aab"),
                overwrite = true,
            )
            branded.copyTo(
                File(dir, "Shrimpsend-android-$flavor-$releaseAbi-$versionLabel.aab"),
                overwrite = true,
            )
        }
    }

    listOf("direct", "play").forEach { flavor ->
        val capFlavor = flavor.replaceFirstChar { it.uppercase() }
        listOf(
            "Debug" to "debug",
            "Profile" to "profile",
            "Release" to "release",
        ).forEach { (taskSuffix, mode) ->
            tasks.findByName("assemble${capFlavor}$taskSuffix")?.doLast {
                postProcessFlutterApks(mode, flavor)
            }
        }
        tasks.findByName("bundle${capFlavor}Release")?.doLast {
            postProcessFlutterBundles("release", flavor)
        }
    }

    listOf(
        "Debug" to "debug",
        "Profile" to "profile",
        "Release" to "release",
    ).forEach { (taskSuffix, mode) ->
        tasks.findByName("assemble$taskSuffix")?.doLast {
            postProcessFlutterApks(mode, "direct")
        }
    }
}
