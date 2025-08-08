/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant

import android.app.Application
import android.util.Log
import com.google.firebase.FirebaseApp
import dev.deliteai.assistant.utils.TAG

class ChatAppApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        try {
            System.loadLibrary("espeak_jni") // Load our JNI bridge (includes eSpeak functions)
            Log.d(TAG, "Successfully loaded espeak_jni library")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Failed to load native libraries", e)
        }

        FirebaseApp.initializeApp(this@ChatAppApplication)
    }
}
