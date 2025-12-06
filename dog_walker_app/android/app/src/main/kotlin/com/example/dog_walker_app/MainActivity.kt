package com.example.dog_walker_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.dogWalkerApp/google_api_key"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getGoogleMapsApiKey") {
                // Try to get from AndroidManifest.xml meta-data
                val apiKey = getGoogleMapsApiKey()
                if (apiKey != null) {
                    result.success(apiKey)
                } else {
                    result.error("UNAVAILABLE", "Google Maps API key not found", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getGoogleMapsApiKey(): String? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, android.content.pm.PackageManager.GET_META_DATA)
            val bundle = appInfo.metaData
            bundle?.getString("com.google.android.geo.API_KEY")
        } catch (e: Exception) {
            null
        }
    }
}
