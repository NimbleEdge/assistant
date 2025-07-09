/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.utils

class LoaderTextProvider {
    var currentState = 0

    private val set1 = listOf(
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
        "Synchronizing context...",
    )

    private val set2 = listOf(
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
        "Harmonizing data...",
    )

    private val set3 = listOf(
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
    )


    private var lastReturned: String? = null

    fun getLoaderText(): String {
        var newText: String

        do {
            newText = when (currentState + 1) {
                0 -> set1.random()
                1 -> set2.random()
                else -> set3.random()
            }
        } while (newText == lastReturned)
        lastReturned = newText
        currentState += 1
        return newText
    }
}
