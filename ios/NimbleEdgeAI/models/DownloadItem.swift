/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct DownloadItem {
    let tempFileURL: URL
    let downloadedFile: URL
    let totalSizeInBytes: Int64
    let displayMessage: String
    
    static func getDefaultDownloadSize() -> Int64 {
        var downloadSize: Int64 = 0
        for file in getDefaultDownloadItem() {
            downloadSize += file.totalSizeInBytes
        }
        return downloadSize
    }
    
    static func getDefaultDownloadItem() -> [DownloadItem] {
        return [
            DownloadItem(
                tempFileURL: FileManager.default
                                     .urls(for: .documentDirectory, in: .userDomainMask)
                                     .first!
                                     .appendingPathComponent("nimbleSDK")
                                     .appendingPathComponent("kokoro_small_unbatched1.2.0inferencePlan.txt.part"),
                downloadedFile: FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)
                    .first!
                    .appendingPathComponent("nimbleSDK")
                    .appendingPathComponent("kokoro_small_unbatched1.2.0inferencePlan.txt"),
                totalSizeInBytes: 56_000_000,
                displayMessage: "Downloading file 2..."
            ),
            DownloadItem(
                tempFileURL: FileManager.default
                                     .urls(for: .documentDirectory, in: .userDomainMask)
                                     .first!
                                     .appendingPathComponent("nimbleSDK")
                                     .appendingPathComponent("llama-31.0.0llm.zip.gz.part"),
                downloadedFile: FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)
                    .first!
                    .appendingPathComponent("nimbleSDK")
                    .appendingPathComponent("llama-31.0.0llm")
                    .appendingPathComponent("embedding_quantized_model.onnx.data"),
                totalSizeInBytes: 800_000_000,
                displayMessage: "Downloading file 3..."
            )
        ]
    }
}
