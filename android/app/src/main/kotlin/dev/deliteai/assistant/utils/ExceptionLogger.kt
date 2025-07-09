/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.utils

import android.os.Bundle
import android.util.Log
import com.google.firebase.Firebase
import com.google.firebase.analytics.analytics

object ExceptionLogger {

    fun log(logTag:String, e : Throwable){
        Firebase.analytics.logEvent(logTag,
            Bundle().apply {
                putString("error_type", e.javaClass.simpleName)
                putString("error_message", e.message)
                putString("stack_trace", Log.getStackTraceString(e).take(1000)) // optional: limit to 1000 chars
            }
        )
        Log.e(TAG, ""+e.message)
    }
}
