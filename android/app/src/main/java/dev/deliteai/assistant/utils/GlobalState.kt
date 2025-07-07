/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.utils

import android.annotation.SuppressLint
import androidx.navigation.NavController

object GlobalState {
    @SuppressLint("StaticFieldLeak")
    var navController: NavController? = null
    var clientId: String? = null
}