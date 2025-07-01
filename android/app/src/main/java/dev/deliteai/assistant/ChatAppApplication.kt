package dev.deliteai.assistant

import android.app.Application
import com.google.firebase.FirebaseApp

class ChatAppApplication:Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)
    }
}