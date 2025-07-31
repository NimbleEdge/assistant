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

    // MARK: - Default Constants

    private static let documentDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }()

    private static let baseDownloadFolder = documentDirectory.appendingPathComponent("nimbleSDK")

    private static let kokoroFileName = "kokoro_small_unbatched1.0.0inferencePlan.txt"
    private static let llamaFolder = "llama-31.0.0llm"
    private static let llamaFileName = "embedding_quantized_model.onnx.data"
    private static let llamaCompressedPartFile = "llama-31.0.0llm.zip.gz.part"

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
                tempFileURL: baseDownloadFolder.appendingPathComponent("\(kokoroFileName).part"),
                downloadedFile: baseDownloadFolder.appendingPathComponent(kokoroFileName),
                totalSizeInBytes: 56_000_000,
                displayMessage: "Downloading file 1..."
            ),
            DownloadItem(
                tempFileURL: baseDownloadFolder.appendingPathComponent(llamaCompressedPartFile),
                downloadedFile: baseDownloadFolder
                    .appendingPathComponent(llamaFolder)
                    .appendingPathComponent(llamaFileName),
                totalSizeInBytes: 800_000_000,
                displayMessage: "Downloading file 2..."
            )
        ]
    }
}
