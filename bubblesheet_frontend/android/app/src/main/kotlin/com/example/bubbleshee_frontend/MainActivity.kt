package com.example.bubbleshee_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register ArUco detector plugin
        flutterEngine.plugins.add(ArucoDetectorPlugin())
    }
}
