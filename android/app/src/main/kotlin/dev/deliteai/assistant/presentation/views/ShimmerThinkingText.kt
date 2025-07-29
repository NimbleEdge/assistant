package dev.deliteai.assistant.presentation.views

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle

@Composable
fun ShimmerThinkingText(
    text: String,
    isActive: Boolean = true,
    baseColor: Color = Color.White.copy(alpha = 0.8f),
    highlightColor: Color = Color.White,
    style: TextStyle = MaterialTheme.typography.bodySmall,
    modifier: Modifier = Modifier
) {
    var textWidthPx by remember { mutableIntStateOf(0) }
    val travel = if (textWidthPx == 0) 600f else textWidthPx.toFloat()

    val transition = rememberInfiniteTransition(label = "shimmer")
    val xAnim by transition.animateFloat(
        initialValue = -travel,
        targetValue = travel * 2f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1300, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "xAnim"
    )

    val brush = remember(baseColor, highlightColor, xAnim, travel) {
        Brush.linearGradient(
            colors = listOf(
                baseColor.copy(alpha = 0.75f),
                highlightColor,
                baseColor.copy(alpha = 0.75f)
            ),
            start = Offset(xAnim - travel, 0f),
            end = Offset(xAnim, 0f)
        )
    }

    if (isActive) {
        Text(
            text = buildAnnotatedString {
                withStyle(SpanStyle(brush = brush)) { append(text) }
            },
            style = style,
            color = Color.Unspecified,
            modifier = modifier.onSizeChanged { textWidthPx = it.width }
        )
    } else {
        Text(
            text = text,
            style = style,
            color = baseColor,
            modifier = modifier
        )
    }
}
