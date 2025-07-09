# NimbleEdge Android AI Assistant

[![Platform](https://img.shields.io/badge/platform-Android-green.svg)](https://www.android.com) [![Language](https://img.shields.io/badge/language-Kotlin-orange.svg)](https://kotlinlang.org) [![UI Toolkit](https://img.shields.io/badge/ui-Jetpack%20Compose-blue.svg)](https://developer.android.com/jetpack/compose)

_A modern, on-device chat application powered by DeliteAI's **NimbleNet** and built entirely with Jetpack Compose._

---

## Table of Contents

- [App Overview](#app-overview)
- [Features](#features)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Testing](#testing)

---

## App Overview

The project focuses on simplicity, rapid iteration and a delightful user experience.

### Tech Stack

| Area             | Tech/Library                                                 |
| ---------------- | ------------------------------------------------------------ |
| Language         | Kotlin                                                       |
| UI               | Jetpack Compose, Material 3                                  |
| Navigation       | `androidx.navigation:navigation-compose`                     |
| AI Runtime       | `dev.deliteai:nimblenet_ktx` & `dev.deliteai:nimblenet_core` |
| Analytics        | Firebase Analytics / Crashlytics                             |

---

## Features

• **Conversational UI** — Chat with the LLM via text or voice.

• **On-Device Inference** — Messages are processed locally using NimbleNet; no server round-trips required.\*

• **First-Run On-boarding** — Animated introduction and permission flow on fresh installs.

• **Session History** — View, revisit and resume previous conversations.

• **Crash Reporting & A/B Flags** — Integrated Firebase stack for production readiness.

---

## Project Structure

```text
android/
├── app/                     # Main Android application module
│   ├── src/main/java/…      # Kotlin sources (view-models, composables, utils)
│   ├── src/main/res/…       # XML, vector assets, Lottie animations, fonts
│   └── build.gradle.kts     # Module Gradle script & dependencies
├── gradle/                  # Version catalog & Gradle wrapper
├── build.gradle.kts         # Root build script
└── settings.gradle.kts      # Gradle settings / included modules
```

---

## Quick Start

### 1. Configuration

Create a `local.properties` file in the project root with your NimbleNet credentials:

```properties
# NimbleNet credentials (REQUIRED)
NIMBLENET_CONFIG_CLIENT_ID=your_client_id
NIMBLENET_CONFIG_CLIENT_SECRET=your_client_secret
NIMBLENET_CONFIG_HOST=https://your-nimblenet-endpoint.com

# Optional — Remote logging
LOGGER_KEY=your_logger_key

# Optional — Release signing (keystore placed at android/android-keystore)
KEYSTORE_PASSWORD=*****
KEYSTORE_ALIAS=your_alias
```

> If the file is missing, placeholder empty strings are injected so the _debug_ build can still compile.

### 2. Clone & Run (Android Studio)

1. `File ▸ Open…` → select the `android` directory.
2. Wait for Gradle sync & IDE indexing to finish.
3. Click **Run ▶︎** to install the _Debug_ variant on a connected device/emulator.

The _release_ job expects a valid keystore as configured above.

---

## Testing

⚠️ **We currently lack comprehensive test coverage and would welcome contributions!**

The standard Gradle test tasks are available:

```bash
# JVM unit tests
./gradlew :app:testDebugUnitTest

# On-device Compose tests
./gradlew :app:connectedDebugAndroidTest
```
