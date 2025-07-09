/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.viewmodels

import dev.deliteai.assistant.domain.features.asr.ASRService
import dev.deliteai.assistant.domain.repositories.CacheRepository
import dev.deliteai.assistant.domain.repositories.RemoteConfigRepository
import dev.deliteai.assistant.utils.AssetDataCopier
import dev.deliteai.assistant.utils.Constants.assetFoldersToCopy
import dev.deliteai.assistant.utils.DeviceTier
import dev.deliteai.assistant.utils.FillerAudioProvider
import dev.deliteai.assistant.utils.GlobalState
import dev.deliteai.assistant.utils.TAG
import dev.deliteai.assistant.utils.getActiveDownloadProgress
import dev.deliteai.assistant.utils.initializeNimbleNetAndWaitForIsReady
import android.app.Activity
import android.app.Application
import android.util.Log
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.takeWhile
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.max
import kotlin.math.pow

class MainViewModel(private val application: Application) : AndroidViewModel(application) {
    private lateinit var remoteConfigRepository: RemoteConfigRepository
    private val cacheRepository = CacheRepository(application)

    var copyStatusVS = mutableStateOf("checking device compatibility...")
    var copyProgressVS = mutableStateOf(0f)
    var isNimbleNetReadyVS = mutableStateOf(false)
    val toastMessagesVS = MutableSharedFlow<String>()
    val blockedUsageMessageVS = mutableStateOf<String?>(null)
    var isP0LoadingVS = mutableStateOf(true)
    var isFirstBootVS = mutableStateOf(true)

    fun initializeApplication() {
        viewModelScope.launch(Dispatchers.IO) {
            val progressJob = startDummyProgress(20)
            remoteConfigRepository = RemoteConfigRepository.init(application)

            //check is the app version discontinued
            val noPermissionMessage =
                remoteConfigRepository.getBlockedMessageForCurrentApp(application)

            val isFirstBoot = cacheRepository.isFirstBoot()

            //device compatibility check
            GlobalState.clientId = getCT() ?: return@launch

            withContext(Dispatchers.Main) {
                isFirstBootVS.value = isFirstBoot
                blockedUsageMessageVS.value = noPermissionMessage
                isP0LoadingVS.value = false
                copyStatusVS.value = "Loading voice data..."
            }

            FillerAudioProvider.loadAudioFillersInMemory(application)

            progressJob.cancel()

            assetFoldersToCopy.forEach {
                AssetDataCopier.copyEspeakDataIfNeeded(application, it)
            }

            onSuccessfulCopy(GlobalState.clientId!!)
        }
    }

    fun registerUserFirstBoot() {
        isFirstBootVS.value = false

        viewModelScope.launch(Dispatchers.IO) {
            cacheRepository.registerUserFirstBoot()

        }
    }

    fun hasUserEverClickedOnChat(): Boolean {
        return cacheRepository.hasUserEverClickedOnChat()
    }

    fun registerUserTapToChat() {
        if (hasUserEverClickedOnChat()) return

        viewModelScope.launch(Dispatchers.IO) {
            cacheRepository.registerUserTapToChat()
        }
    }

    private fun shouldAskForAppReview(): Boolean {
        val appOpenCount: Int = cacheRepository.getAppStartCount()
        cacheRepository.incrementAppStartCount()

        var targetOpenCount = 3
        var power = 0

        while (targetOpenCount <= appOpenCount) {
            if (appOpenCount == targetOpenCount) {
                return true
            }
            power++
            targetOpenCount = (3 * 2.0.pow(power)).toInt()
        }

        return false
    }

    fun triggerInAppReview(activity: Activity) {
        viewModelScope.launch(Dispatchers.IO) {
            if (!shouldAskForAppReview()) {
                Log.d(TAG, "Not yet time to ask for app review.")
                return@launch
            }

            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (request.isSuccessful) {
                    val reviewInfo = request.result
                    Log.d(TAG, "Review flow requested successfully.")
                    manager.launchReviewFlow(activity, reviewInfo)
                        .addOnCompleteListener { launchTask ->
                            if (launchTask.isSuccessful) {
                                Log.d(TAG, "Review flow launched successfully.")
                            } else {
                                Log.e(
                                    TAG,
                                    "Review flow launch failed: ${launchTask.exception?.message}",
                                    launchTask.exception
                                )
                            }
                        }
                } else {
                    Log.e(
                        TAG,
                        "Review flow request failed: ${request.exception?.message}",
                        request.exception
                    )
                }
            }
        }
    }

    private fun getCT(): String? {
        val scriptVersion = "v1.0.1"

        val deviceTier = when (remoteConfigRepository.getDeviceTier()) {
            DeviceTier.ONE -> "CHATAPP_TIER_1"
            DeviceTier.TWO -> "CHATAPP_TIER_2"
            DeviceTier.UNSUPPORTED -> {
                blockedUsageMessageVS.value = "This device is not compatible with NimbleEdge AI"
                return null
            }
        }
        return (if (ASRService.googleASRIsAvailable(application)) "${deviceTier}_GOOGLE_ASR" else deviceTier) + "_$scriptVersion"
    }

    private fun onSuccessfulCopy(ct: String) {
        viewModelScope.launch {
            copyStatusVS.value = "Initializing NimbleEdge AI"
            var dummyProgressJob: Job = startDummyProgress(20)

            val downloadProgressMonitorJob = startAssetDownloadMonitoring(onDownloadStart = {
                dummyProgressJob.cancel()
            }, onDownloadFinish = {
                copyStatusVS.value = "Preparing your private AI assistant"
                dummyProgressJob = startDummyProgress(50)
            })

            val nimblenetInitJob = async(Dispatchers.Default) {
                try {
                    initializeNimbleNetAndWaitForIsReady(application, ct)
                } catch (e: Exception) {
                    copyStatusVS.value = "Initialization failed: ${e.message}"
                    this@launch.cancel("Init error", e)
                }
            }

            nimblenetInitJob.await()

            if (downloadProgressMonitorJob.isActive) {
                downloadProgressMonitorJob.cancel()
            }

            if (dummyProgressJob.isActive) {
                dummyProgressJob.cancel()
            }

            copyStatusVS.value = "Let's start!"
            copyProgressVS.value = 100f

            withContext(Dispatchers.IO) {
                delay(500)
            }
            isNimbleNetReadyVS.value = true
        }
    }

    private fun startAssetDownloadMonitoring(
        onDownloadStart: () -> Unit,
        onDownloadFinish: () -> Unit
    ): Job =
        viewModelScope.launch(Dispatchers.IO) {
            var isFirstCheck = true
            var maxAssets = 0

            while (true) {
                val progress = getActiveDownloadProgress(application)
                Log.d(TAG, "startAssetDownloadMonitoring: $progress")

                if (progress.isNotEmpty()) {
                    isFirstCheck = false
                    onDownloadStart()

                    withContext(Dispatchers.Main) {
                        maxAssets = max(progress.size, maxAssets)
                        val downloadAvg =
                            (progress.sumOf { it.downloadPercentage } + (maxAssets - progress.size) * 100) / maxAssets.toFloat()
                        copyProgressVS.value = downloadAvg
                        copyStatusVS.value = "Downloading assets"
                    }
                } else if (!isFirstCheck) {
                    onDownloadFinish()
                    break
                }

                delay(50)
            }
        }

    private fun startDummyProgress(maxDuration: Int): Job = viewModelScope.launch(Dispatchers.IO) {
        emitDummyPercentage(maxDuration)
            .onEach {
                withContext(Dispatchers.Main) {
                    copyProgressVS.value = it
                }
            }
            .takeWhile { it < 100f }
            .collect {}
    }


    private fun emitDummyPercentage(
        durationSeconds: Int,
        intervalMillis: Long = 100L
    ): Flow<Float> = flow {
        val totalMillis = durationSeconds * 1_000L
        var elapsed = 0L

        emit(0f)
        while (elapsed < totalMillis) {
            delay(intervalMillis)
            elapsed += intervalMillis
            val progress = (elapsed.toFloat() / totalMillis) * 100f
            emit(progress.coerceAtMost(100f))
        }
    }

    fun showToast(message: String) {
        viewModelScope.launch(Dispatchers.Main) {
            toastMessagesVS.emit(message)
        }
    }
}
