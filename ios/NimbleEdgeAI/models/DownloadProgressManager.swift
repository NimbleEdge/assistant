/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NimbleNetiOS

class DownloadProgressManager: ObservableObject {
    @Published var percentageCompleted: Float = 0.0
    @Published var currentMessage: String = ""
    @Published var downloadedSizeText: String = ""
    @Published var llmDowonloadIsReady = false
    
    private var files: [DownloadItem]
    private var currentIndex = 0
    private var timer: Timer?
    private let fileManager = FileManager.default
    private var wasDownloadingStarted: [String: Bool] = [:] //cache to know the downloading was started for the file URL
    private var totalFileSize: Int64 = 0

    init(files: [DownloadItem]) {
        self.files = files
        for file in files { totalFileSize += file.totalSizeInBytes  }
        startMonitoringCurrentFile()
    }

    private func startMonitoringCurrentFile() {
        DispatchQueue.main.async(execute: { [weak self] in
            self?.currentMessage = "Downloading assets"
        })
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        
        var currentSize: Int64 = 0
        for file in files {
            currentSize += getFileSize(file: file)
        }
        
        let percentage = min(Float(currentSize) / Float(totalFileSize) * 100.0, 100.0)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            percentageCompleted = min(percentage, 100.0)    
            downloadedSizeText = "\(currentSize.asReadableSize()) / \(totalFileSize.asReadableSize())"
        }

        if percentage >= 100.0 {
            timer?.invalidate()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                currentMessage = "All downloads completed. Initializing...."
                downloadedSizeText = ""
                
                //checking if sdk isReady
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
                    
                    if NimbleNetApi.isReady().status == true {
                        self.llmDowonloadIsReady = true
                        self.timer?.invalidate()
                    } else {
                        
                        //checking if sdk is redownling the file, if yes then showing its progress
                        for (index, file) in self.files.enumerated() {
                            if self.fileManager.fileExists(atPath: file.tempFileURL.path) {
                                self.wasDownloadingStarted.removeAll()
                                self.timer?.invalidate()
                                self.startMonitoringCurrentFile()
                            }
                        }
                    }
                })
            }
        }
    }
    
    private func getFileSize(file: DownloadItem) -> Int64 {
        guard fileManager.fileExists(atPath: file.tempFileURL.path) else {
            
            // If the file download was started and now it does not exist, then the download is completed.
            // Or if the file download was not started but the actual file is present, then the download is completed.
            if fileManager.fileExists(atPath: file.downloadedFile.path) || wasDownloadingStarted[file.tempFileURL.path] == true {
                return file.totalSizeInBytes
            } else {
                return 0
            }
        }
        
        wasDownloadingStarted[file.tempFileURL.path] = true

        do {
            let attributes = try fileManager.attributesOfItem(atPath: file.tempFileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return -1
        }
    }

    deinit {
        timer?.invalidate()
    }
}
