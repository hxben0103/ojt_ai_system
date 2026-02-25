package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.flutter_application_1.location.MockLocationChecker

class MainActivity : FlutterActivity() {

    private val channelName = "location_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "isMockLocationEnabled") {
                val enabled = MockLocationChecker.isMockLocationEnabled(applicationContext)
                result.success(enabled)
            } else {
                result.notImplemented()
            }
        }
    }
}
