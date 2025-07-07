/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.asr

import android.content.Context
import kotlinx.coroutines.flow.Flow

object ASRService {

    private lateinit var asrManager: ASRManagerInterface
    private var isPermissionGranted = false

    fun init(context: Context, isPermissionGiven : Boolean) {
        isPermissionGranted = isPermissionGiven
        if (isPermissionGranted)
            asrManager = getASRManager(context)
    }

    fun startAndroidListener() : Flow<ASRState> {
        if (!isPermissionGranted)
            throw SecurityException("Please provide permission to record Audio for Listening")

        return asrManager.startListeningFlow()
    }

    fun googleASRIsAvailable(context: Context) = GoogleASRManager.isAvailable(context)

    private fun getASRManager(context: Context): ASRManagerInterface {
        return if (GoogleASRManager.isAvailable(context))
            GoogleASRManager(context)
        else
            WhisperASRManager()
    }
}