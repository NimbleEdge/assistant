/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.presentation.components

import ai.nimbleedge.nimbleedge_chatbot.domain.models.ChatMessage
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accentHigh1
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accentLow1
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.backgroundSecondary
import ai.nimbleedge.nimbleedge_chatbot.presentation.viewmodels.ChatViewModel
import ai.nimbleedge.nimbleedge_chatbot.utils.formatTimeUsingSimpleDateFormat
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.ripple
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.halilibo.richtext.commonmark.Markdown
import com.halilibo.richtext.ui.BlockQuoteGutter
import com.halilibo.richtext.ui.CodeBlockStyle
import com.halilibo.richtext.ui.InfoPanelStyle
import com.halilibo.richtext.ui.InfoPanelType
import com.halilibo.richtext.ui.ListStyle
import com.halilibo.richtext.ui.RichTextStyle
import com.halilibo.richtext.ui.TableStyle
import com.halilibo.richtext.ui.material3.RichText
import com.halilibo.richtext.ui.string.RichTextStringStyle
import kotlinx.coroutines.delay


@Composable
fun ColumnScope.MessageBox(
    message: ChatMessage,
    chatViewModel: ChatViewModel,
    isInProgress: Boolean = false,
    onLongTap: (offset: Offset, layoutCoordinates: LayoutCoordinates) -> Unit
) {
    if (message.message == null) return
    val markdownRichTextStyle = rememberMarkdownStyle()
    var layoutCoordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val interactionSource = remember { MutableInteractionSource() }

    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = if (message.isUserMessage) Arrangement.End else Arrangement.Start
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .padding(
                    start = if (message.isUserMessage) 52.dp else 0.dp,
                    end = if (message.isUserMessage) 0.dp else 52.dp
                )
                .onGloballyPositioned { coordinates ->
                    layoutCoordinates = coordinates
                }
                .clickable(
                    interactionSource = interactionSource,
                    indication = ripple(),
                    onClick = {}
                )
                .pointerInput(Unit) {
                    detectTapGestures(
                        onLongPress = { offset ->
                            layoutCoordinates?.let { coordinates ->
                                onLongTap(offset, coordinates)
                            }
                        },
                        onPress = {
                            val press = PressInteraction.Press(it)
                            interactionSource.emit(press)
                            tryAwaitRelease()
                            interactionSource.emit(PressInteraction.Release(press))
                        }
                    )
                }
                .clip(
                    RoundedCornerShape(
                        topStart = 12.dp,
                        topEnd = 12.dp,
                        bottomStart = if (message.isUserMessage) 12.dp else 0.dp,
                        bottomEnd = if (message.isUserMessage) 0.dp else 12.dp
                    )
                )
                .background(if (message.isUserMessage) backgroundSecondary else accentLow1)
                .padding(12.dp)

        ) {
            if (chatViewModel.currentMessageLoading.value && isInProgress) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(24.dp), color = accentHigh1)
                    Spacer(Modifier.padding(8.dp))

                    AnimatedTypewriterText(
                        text = chatViewModel.currentWaitText.value,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            } else {
                Column {
                    ProvideTextStyle(MaterialTheme.typography.bodyMedium) {
                        RichText(style = markdownRichTextStyle) {
                            var cleanedMessage = message.message.trim().trimIndent()
                            if (cleanedMessage.startsWith('"') && cleanedMessage.endsWith('"')) {
                                Markdown(cleanedMessage.trim('"'))
                            } else {
                                Markdown((cleanedMessage))
                            }
                        }
                    }
                    if (!isInProgress) {
                        Spacer(Modifier.height(8.dp))

                        val timeLabel = if (message.isUserMessage) {
                            "${formatTimeUsingSimpleDateFormat(message.timestamp)} · Sent"
                        } else {
                            formatTimeUsingSimpleDateFormat(message.timestamp)
                        }

                        Text(
                            timeLabel,
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                            textAlign = TextAlign.Start,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun rememberMarkdownStyle(): RichTextStyle {
    // 1️⃣  Pull the current theme values *inside* the composable
    val typography = MaterialTheme.typography
    val colors = MaterialTheme.colorScheme
    return remember(typography, colors) {
        RichTextStyle(
            /* 1 -- block-level spacing */
            paragraphSpacing = 8.sp,

            /* 2 -- headings */
            headingStyle = null,

            /* 3 -- bullet / ordered lists */
            listStyle = ListStyle(
                markerIndent = 8.sp,
                contentsIndent = 4.sp,
                itemSpacing = 4.sp
            ),                                                           /* :contentReference[oaicite:0]{index=0} */

            /* 4 -- > block quotes */
            blockQuoteGutter = BlockQuoteGutter.BarGutter(
                startMargin = 6.sp,
                barWidth = 3.sp,
                endMargin = 6.sp,
                color = { it.copy(alpha = .25f) }
            ),                                                            /* :contentReference[oaicite:1]{index=1} */

            /* 5 -- fenced code blocks */
            codeBlockStyle = CodeBlockStyle(
                textStyle = typography.bodySmall.copy(
                    fontFamily = FontFamily.Monospace
                ),
                padding = 8.sp,
                wordWrap = true
            ),                                                            /* :contentReference[oaicite:2]{index=2} */

            /* 6 -- tables */
            tableStyle = TableStyle(
                headerTextStyle = typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                cellPadding = 6.sp,
                borderColor = colors.outline,
                borderStrokeWidth = 1f
            ),                                                            /* :contentReference[oaicite:3]{index=3} */

            /* 7 -- call-out / info panels */
            infoPanelStyle = InfoPanelStyle(
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                background = { type ->
                    val c = colors
                    Modifier.background(
                        when (type) {
                            InfoPanelType.Primary -> c.primaryContainer
                            InfoPanelType.Secondary -> c.secondaryContainer
                            InfoPanelType.Success -> c.tertiaryContainer
                            InfoPanelType.Danger,
                            InfoPanelType.Warning -> c.errorContainer
                        }
                    )
                },
                textStyle = { MaterialTheme.typography.bodyMedium }
            ),                                                            /* :contentReference[oaicite:4]{index=4} */

            /* 8 -- inline span styles */
            stringStyle = RichTextStringStyle(

                /* default body text = what you used to render with bodyMedium */
                boldStyle = SpanStyle(fontWeight = FontWeight.Bold),
                italicStyle = SpanStyle(fontStyle = FontStyle.Italic),
                underlineStyle = SpanStyle(textDecoration = TextDecoration.Underline),
                codeStyle = SpanStyle(
                    fontFamily = FontFamily.Monospace,
                    background = colors.surfaceVariant
                ),
                linkStyle = TextLinkStyles(
                    style = SpanStyle(color = colors.primary)
                )
            )                                                             /* :contentReference[oaicite:5]{index=5} */
        )
    }
}

@Composable
fun AnimatedTypewriterText(
    text: String,
    style: TextStyle,
    charDelay: Long = 20L
) {
    var displayText by remember { mutableStateOf("") }

    LaunchedEffect(text) {
        displayText = ""
        text.forEach { character ->
            displayText += character
            delay(charDelay)
        }
    }

    Text(text = displayText, style = style)
}



