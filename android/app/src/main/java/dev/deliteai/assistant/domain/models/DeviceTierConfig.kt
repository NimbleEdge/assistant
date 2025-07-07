/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.models

import org.json.JSONObject

data class TierConfig(
    val minMultiCoreScore: Int,
    val minRam: Int,
    val minNumCores: Int
)

data class BenchmarkEntry(
    val device: String,
    val chipset: String,
    val multiCoreScore: Int
)

data class DeviceTierConfig(
    val tier1: TierConfig,
    val tier2: TierConfig,
    val historicalBenchmarks: List<BenchmarkEntry>
) {
    companion object {
        fun fromRawJson(jsonString: String): DeviceTierConfig {
            val json = JSONObject(jsonString)
            val tierConfig = json.getJSONObject("tier_config")
            val tier1Config = tierConfig.getJSONObject("tier_1")
            val tier2Config = tierConfig.getJSONObject("tier_2")

            val benchmarks = json.getJSONArray("historical_benchmarks")
            val benchmarksList = mutableListOf<BenchmarkEntry>()
            
            for (i in 0 until benchmarks.length()) {
                val benchmark = benchmarks.getJSONObject(i)
                benchmarksList.add(
                    BenchmarkEntry(
                        device = benchmark.getString("device"),
                        chipset = benchmark.getString("chipset"),
                        multiCoreScore = benchmark.getInt("multi_core_score")
                    )
                )
            }

            return DeviceTierConfig(
                tier1 = TierConfig(
                    minMultiCoreScore = tier1Config.getInt("min_multi_core_score"),
                    minRam = tier1Config.getInt("min_ram"),
                    minNumCores = tier1Config.getInt("min_num_cores")
                ),
                tier2 = TierConfig(
                    minMultiCoreScore = tier2Config.getInt("min_multi_core_score"), 
                    minRam = tier2Config.getInt("min_ram"),
                    minNumCores = tier2Config.getInt("min_num_cores")
                ),
                historicalBenchmarks = benchmarksList
            )
        }
    }
}
