/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import java.util.Properties

val localProps = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        load(file.inputStream())
    }
}

val clientId = localProps.getProperty("NIMBLENET_CONFIG_CLIENT_ID") ?: ""
val clientSecret = localProps.getProperty("NIMBLENET_CONFIG_CLIENT_SECRET") ?: ""
val host = localProps.getProperty("NIMBLENET_CONFIG_HOST") ?: ""
val keystorePassword = localProps.getProperty("KEYSTORE_PASSWORD") ?: ""
val keystoreAlias = localProps.getProperty("KEYSTORE_ALIAS") ?: ""
val loggerKey = localProps.getProperty("LOGGER_KEY") ?: ""

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    signingConfigs {
        create("release") {
            storeFile = file("./android-keystore")
            storePassword = keystorePassword
            keyAlias = keystoreAlias
            keyPassword = keystorePassword
        }
    }
    namespace = "dev.deliteai.assistant"
    compileSdk = 35

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "ai.nimbleedge.nimbleedge_chatbot"
        minSdk = 31
        targetSdk = 35
        versionCode = 5
        versionName = "1.1.1"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "NIMBLENET_CONFIG_CLIENT_ID", "\"$clientId\"")
        buildConfigField("String", "NIMBLENET_CONFIG_CLIENT_SECRET", "\"$clientSecret\"")
        buildConfigField("String", "NIMBLENET_CONFIG_HOST", "\"$host\"")
        buildConfigField("String", "LOGGER_KEY", "\"$loggerKey\"")
        
        // Specify supported ABIs for the native libraries
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
        }
        
        // External native build configuration
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
                arguments += listOf("-DANDROID_STL=c++_shared")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
    }
    
    // NDK configuration for JNI support
    ndkVersion = "25.1.8937393"
    
    // External native build configuration
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation("com.google.accompanist:accompanist-systemuicontroller:0.36.0")
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)

    implementation("dev.deliteai:nimblenet_ktx:0.0.1-dev-1751902318")
    implementation("dev.deliteai:nimblenet_core:0.0.1-dev-1751904491")

    implementation("com.halilibo.compose-richtext:richtext-ui-material3:1.0.0+")
    implementation("com.halilibo.compose-richtext:richtext-commonmark:1.0.0+")

    implementation("com.airbnb.android:lottie:6.6.4")

    implementation("com.airbnb.android:lottie-compose:6.6.4")
    implementation("br.com.devsrsouza.compose.icons.android:feather:1.0.0")
    implementation("androidx.navigation:navigation-compose:2.7.6")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-config")
    implementation("com.google.firebase:firebase-crashlytics")
    implementation("androidx.compose.material:material-icons-extended:1.7.8")
    implementation("nl.dionsegijn:konfetti-compose:2.0.5")
    implementation("com.google.android.play:review:2.0.2")
    implementation("com.google.android.play:review-ktx:2.0.2")
}
