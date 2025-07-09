/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.models

data class AssetDownloadProgress(
    val name: String,
    val downloadPercentage: Int
){
    override fun toString(): String {
        return "$name:$downloadPercentage"
    }
}
