package dev.deliteai.assistant

import dev.deliteai.assistant.presentation.ui.theme.DeliteAiChatBotTheme
import dev.deliteai.assistant.presentation.ui.theme.accentHigh1
import dev.deliteai.assistant.presentation.ui.theme.backgroundPrimary
import dev.deliteai.assistant.presentation.viewmodels.ChatViewModel
import dev.deliteai.assistant.presentation.viewmodels.HistoryViewModel
import dev.deliteai.assistant.presentation.viewmodels.MainViewModel
import dev.deliteai.assistant.presentation.views.ChatView
import dev.deliteai.assistant.presentation.views.HistoryView
import dev.deliteai.assistant.presentation.views.HomeView
import dev.deliteai.assistant.presentation.views.InitStatusView
import dev.deliteai.assistant.presentation.views.IntroductionPage
import dev.deliteai.assistant.presentation.views.NoAccessView
import dev.deliteai.assistant.utils.AudioPermissionLauncher
import dev.deliteai.assistant.utils.Constants
import dev.deliteai.assistant.utils.GlobalState
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.google.accompanist.systemuicontroller.rememberSystemUiController

class MainActivity : ComponentActivity() {
    private val mainViewModel: MainViewModel by viewModels {
        ViewModelProvider.AndroidViewModelFactory.getInstance(application)
    }
    private val chatViewModel: ChatViewModel by viewModels {
        ViewModelProvider.AndroidViewModelFactory.getInstance(application)
    }
    private val historyViewModel: HistoryViewModel by viewModels {
        ViewModelProvider.AndroidViewModelFactory.getInstance(application)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        //Toast Listener
        lifecycleScope.launchWhenStarted {
            mainViewModel.toastMessagesVS.collect { msg ->
                Toast.makeText(this@MainActivity.application, msg, Toast.LENGTH_LONG).show()
            }
        }

        mainViewModel.triggerInAppReview(this)

        setContent {
            DeliteAiChatBotTheme {
                val systemUiController = rememberSystemUiController()
                SideEffect {
                    systemUiController.setStatusBarColor(
                        color = backgroundPrimary,
                        darkIcons = false
                    )
                    systemUiController.setNavigationBarColor(
                        color = backgroundPrimary,
                        darkIcons = false
                    )
                }
                Scaffold(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(backgroundPrimary)
                ) { innerPadding ->
                    Router(
                        modifier = Modifier
                            .background(backgroundPrimary)
                            .padding(innerPadding),
                        historyViewModel = historyViewModel,
                        chatViewModel = chatViewModel,
                        mainViewModel = mainViewModel,
                    )
                }
            }
        }
    }

    override fun onPause() {
        super.onPause()
        chatViewModel.cancelLLMAndClearAudioQueue()
    }
}

@Composable
fun Router(
    modifier: Modifier = Modifier,
    mainViewModel: MainViewModel,
    chatViewModel: ChatViewModel,
    historyViewModel: HistoryViewModel,
) {
    AudioPermissionLauncher(mainViewModel)

    LaunchedEffect(Unit) {
        mainViewModel.initializeApplication()
    }

    if (mainViewModel.isP0LoadingVS.value && mainViewModel.blockedUsageMessageVS.value == null) {
        Box(
            Modifier
                .background(backgroundPrimary)
                .fillMaxSize()
        ) {
            CircularProgressIndicator(Modifier.align(Alignment.Center), color = accentHigh1)
        }
    } else if (mainViewModel.blockedUsageMessageVS.value != null) {
        NoAccessView(mainViewModel.blockedUsageMessageVS.value!!)
    } else if (mainViewModel.isFirstBootVS.value) {
        IntroductionPage(modifier = modifier) {
            mainViewModel.registerUserFirstBoot()
        }
    } else if (!mainViewModel.isNimbleNetReadyVS.value) {
        InitStatusView(mainViewModel.copyStatusVS.value, mainViewModel.copyProgressVS.value)
    } else {
        val navController = rememberNavController()
        GlobalState.navController = navController

        NavHost(
            navController = navController,
            startDestination = Constants.VIEWS.HOME_VIEW.str,
            modifier = modifier
        ) {
            composable(Constants.VIEWS.HOME_VIEW.str) {
                HomeView(mainViewModel, historyViewModel)
            }
            composable(Constants.VIEWS.HISTORY_VIEW.str) {
                HistoryView(
                    historyViewModel = historyViewModel,
                    navController = navController,
                    chatViewModel = chatViewModel
                )
            }
            composable(Constants.VIEWS.CHAT_VIEW.str) {
                ChatView(chatViewModel, navController, false)
            }
            composable(
                route = "${Constants.VIEWS.CHAT_VIEW.str}/{chatId}",
                arguments = listOf(navArgument("chatId") { type = NavType.StringType })
            ) { backStackEntry ->
                val id = backStackEntry.arguments?.getString("chatId")
                ChatView(chatViewModel, navController, false, id)
            }
            composable(Constants.VIEWS.VOICE_VIEW.str) {
                ChatView(chatViewModel, navController, true)
            }
        }
    }
}
