plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ✅ Richtige Kotlin-ID
    id("com.google.gms.google-services") // ✅ Für Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.seitendorf.kneipentour"
    compileSdk = 36 // Firebase unterstützt derzeit 34 sicher (36 optional)
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "de.seitendorf.kneipentour"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            isShrinkResources = false   // 👈 ändern!
            isMinifyEnabled = false     // (optional, klarstellen)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 🔥 Firebase BOM (alle Versionen zentral)
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

    // ✨ Nur die Firebase-Module, die du wirklich brauchst:
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging") // für Push-Notifications (später nützlich)

    // ✅ Kotlin und Android Core
    implementation("androidx.core:core-ktx:1.12.0")
}
