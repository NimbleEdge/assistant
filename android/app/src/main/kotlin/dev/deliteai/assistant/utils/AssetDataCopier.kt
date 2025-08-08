/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.utils

import android.content.Context
import java.io.File
import java.io.FileOutputStream


object AssetDataCopier {
    fun copyEspeakDataIfNeeded(context: Context, assetPath: String) {
        val prefs = context.getSharedPreferences(assetPath, Context.MODE_PRIVATE)
        val alreadyCopied = prefs.getBoolean(assetPath, false)

        if (alreadyCopied) return

        try {
            val outputFolder = File(context.filesDir, "nimbleSDK")
            copyAssetFolder(context, assetPath, outputFolder)
            prefs.edit().putBoolean(assetPath, true).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun copyAssetFolder(context: Context, assetPath: String, outDir: File) {
        val assetManager = context.assets
        val assets = assetManager.list(assetPath) ?: return

        if (!outDir.exists()) {
            outDir.mkdirs()
        }

        for (asset in assets) {
            val subPath = "$assetPath/$asset"
            val outFile = File(outDir, asset)

            val subAssets = assetManager.list(subPath)
            if (subAssets.isNullOrEmpty()) {
                // It's a file
                if (!outFile.exists()) {
                    assetManager.open(subPath).use { inputStream ->
                        FileOutputStream(outFile).use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                }
            } else {
                // It's a folder
                copyAssetFolder(context, subPath, outFile)
            }
        }
    }
}
