/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.data.remote

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

class Networking {
    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    @Throws(IOException::class)
    suspend fun get(url: String, headers: Map<String, String> = emptyMap()): String {
        val requestBuilder = Request.Builder().url(url)
        headers.forEach { (key, value) -> 
            requestBuilder.addHeader(key, value)
        }
        val request = requestBuilder.build()
        client.newCall(request).execute().use { response ->
            return response.body?.string() ?: ""
        }
    }

    @Throws(IOException::class) 
    suspend fun post(url: String, body: String, headers: Map<String, String> = emptyMap()): String {
        val requestBody = body.toRequestBody(jsonMediaType)
        val requestBuilder = Request.Builder()
            .url(url)
            .post(requestBody)
        headers.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }
        val request = requestBuilder.build()
        client.newCall(request).execute().use { response ->
            return response.body?.string() ?: ""
        }
    }
}
