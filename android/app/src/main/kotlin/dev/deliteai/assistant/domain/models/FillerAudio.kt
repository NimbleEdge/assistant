/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.models

data class FillerAudio(
    val data: ShortArray,
    var hasPlayed: Boolean = false
)
