/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class AtomicInteger {
    private var value: Int
    private let lock = NSLock()
    
    init(value: Int) {
        self.value = value
    }
    
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let result = value
        value += 1
        return result
    }
    
    func getAndIncrement() -> Int {
        return increment()
    }
}
