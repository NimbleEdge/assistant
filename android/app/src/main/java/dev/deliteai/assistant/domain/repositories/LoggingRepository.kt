/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.repositories

import ai.nimbleedge.nimbleedge_chatbot.BuildConfig
import ai.nimbleedge.nimbleedge_chatbot.data.remote.Networking
import ai.nimbleedge.nimbleedge_chatbot.utils.getInternalDeviceId
import android.app.Application
import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

class LoggingRepository {
    private val networking = Networking()
    private val loggerUrl = "https://logs.nimbleedge.com/v2"

    suspend fun flagLLMMessage(application: Application, chatMessage: String?) {
        if (chatMessage == null) return

        val body = mapOf(
            "message" to chatMessage
        )

        val logLine = getMetricsLog("FLAGGED_MESSAGE", JSONObject(body).toString())

        val headers = mapOf(
            "Secret-Key" to BuildConfig.LOGGER_KEY,
            "clientId" to BuildConfig.NIMBLENET_CONFIG_CLIENT_ID,
            "deviceID" to getInternalDeviceId(application)
        )

        networking.post(loggerUrl, logLine, headers)
    }

    private fun getMetricsLog(metricName: String, jsonString: String): String {
        val timestamp = OffsetDateTime.now(ZoneOffset.UTC)
            .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSSxxx"))
        return "METRICS::: $timestamp ::: $metricName ::: $jsonString"
    }
}