/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.utils

import dev.deliteai.assistant.domain.features.asr.ASRService
import dev.deliteai.assistant.presentation.viewmodels.MainViewModel
import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect

@Composable
fun AudioPermissionLauncher(mainViewModel: MainViewModel) {
    val audioPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        ASRService.init(mainViewModel.getApplication(), isGranted)
        if (!isGranted)
            mainViewModel.showToast("Please provide audio permission for ASR")
    }
    LaunchedEffect(Unit) {
        audioPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }
}
