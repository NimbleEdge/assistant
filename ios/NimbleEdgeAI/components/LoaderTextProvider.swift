/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

class LoaderTextProvider {
    var currentState = 0

    private let set1 = [
        "Thinking...",
        "Analyzing...",
        "Reviewing details...",
        "Processing your request...",
        "Looking for insights...",
        "Retrieving context...",
        "Processing query...",
        "Delving into context...",
        "Parsing input...",
        "Verifying details...",
        "Mapping concepts...",
        "Adjusting logic...",
        "Synchronizing context..."
    ]

    private let set2 = [
        "Gathering thoughts...",
        "Calculating possibilities...",
        "Deliberating options...",
        "Generating ideas...",
        "Ensuring accuracy...",
        "Digging deeper...",
        "Compiling information...",
        "Evaluating data...",
        "Summarizing thoughts…",
        "Weighing alternatives...",
        "Synthesizing insights...",
        "Integrating knowledge...",
        "Orchestrating ideas...",
        "Streamlining thought...",
        "Focusing ideas...",
        "Aligning perspectives...",
        "Harmonizing data..."
    ]

    private let set3 = [
        "Formulating a response...",
        "Optimizing output...",
        "Building a reply...",
        "Crafting language...",
        "Aligning outputs...",
        "Constructing narrative...",
        "Evaluating responses...",
        "Updating parameters...",
        "Tailoring answer...",
        "Merging insights...",
        "Polishing the reply..."
    ]

    private var lastReturned: String?

    func getLoaderText() -> String {
        var newText: String

        repeat {
            switch currentState {
            case 0:
                newText = set1.randomElement() ?? "Thinking..."
            case 1:
                newText = set2.randomElement() ?? "Gathering thoughts..."
            default:
                newText = set3.randomElement() ?? "Formulating a response..."
            }
        } while newText == lastReturned

        lastReturned = newText
        currentState += 1
        return newText
    }
}
