/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.repositories

import ai.nimbleedge.nimbleedge_chatbot.domain.models.DeviceTierConfig
import ai.nimbleedge.nimbleedge_chatbot.utils.Constants.defaultRemoteConfig
import ai.nimbleedge.nimbleedge_chatbot.utils.DeviceTier
import ai.nimbleedge.nimbleedge_chatbot.utils.getCurrentAppVersionCode
import ai.nimbleedge.nimbleedge_chatbot.utils.getDeviceName
import ai.nimbleedge.nimbleedge_chatbot.utils.getNumCores
import ai.nimbleedge.nimbleedge_chatbot.utils.getRamInGb
import ai.nimbleedge.nimbleedge_chatbot.utils.getSoc
import android.app.Application
import android.content.Context
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray

class RemoteConfigRepository private constructor(private val application: Context) {
    private val remoteConfig = FirebaseRemoteConfig.getInstance()
    private val initJob: Job = CoroutineScope(Dispatchers.IO).launch {
        val settings = FirebaseRemoteConfigSettings.Builder()
            .setMinimumFetchIntervalInSeconds(0)
            .build()
        remoteConfig.setConfigSettingsAsync(settings).await()
        runCatching { remoteConfig.fetchAndActivate().await() }
    }

    companion object {
        suspend fun init(context: Context): RemoteConfigRepository {
            val instance = RemoteConfigRepository(context)
            instance.initJob.join()
            return instance
        }
    }

    fun getDeviceTier(): DeviceTier {
        val deviceName = getDeviceName()
        val deviceChipset = getSoc()
        val deviceRam = getRamInGb(application)
        val deviceNumCores = getNumCores()
        val deviceTierConfigString = remoteConfig.getString("device_tier_config")
        val config = try {
            DeviceTierConfig.fromRawJson(deviceTierConfigString)
        } catch (e: Exception) {
            DeviceTierConfig.fromRawJson(defaultRemoteConfig.toString())
        }

        // Check historical benchmarks based on device name or chipset.
        config.historicalBenchmarks.forEach { benchmark ->
            if (benchmark.device.equals(deviceName, ignoreCase = true) ||
                benchmark.chipset.equals(deviceChipset, ignoreCase = true)
            ) {
                if (benchmark.multiCoreScore >= config.tier1.minMultiCoreScore) {
                    return DeviceTier.ONE
                }
                if (benchmark.multiCoreScore >= config.tier2.minMultiCoreScore) {
                    return DeviceTier.TWO
                }
            }
        }

        if (deviceRam >= config.tier1.minRam && deviceNumCores >= config.tier1.minNumCores) {
            return DeviceTier.ONE
        }
        if (deviceRam >= config.tier2.minRam && deviceNumCores >= config.tier2.minNumCores) {
            return DeviceTier.TWO
        }

        return DeviceTier.UNSUPPORTED
    }

    fun getBlockedMessageForCurrentApp(application: Application): String? {
        val jsonStr = remoteConfig.getString("blocked_versions")
        val currentVersion = getCurrentAppVersionCode(application)
        return runCatching {
            JSONArray(jsonStr).let { arr ->
                (0 until arr.length()).asSequence()
                    .map { arr.getJSONObject(it) }
                    .firstOrNull { it.optInt("versionCode", -1) == currentVersion }
                    ?.optString("message")
            }
        }.getOrNull()
    }
}
