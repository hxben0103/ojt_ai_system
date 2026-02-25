package com.example.flutter_application_1.location

import android.content.Context
import android.location.Location
import android.os.Build
import android.provider.Settings

/**
 * Checks if the device is using mock location (Fake GPS / developer option).
 * Used by Flutter via method channel for attendance trust scoring.
 */
object MockLocationChecker {

    /**
     * Returns true if mock locations are enabled (e.g. Fake GPS app or developer option).
     * Note: ALLOW_MOCK_LOCATION is deprecated on API 23+ and may be unreliable; used as best-effort.
     */
    @JvmStatic
    fun isMockLocationEnabled(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                @Suppress("DEPRECATION")
                Settings.Secure.getInt(
                    context.contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION,
                    0
                ) == 1
            } else {
                @Suppress("DEPRECATION")
                Settings.Secure.getInt(
                    context.contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION,
                    0
                ) == 1
            }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Returns true if the given Location is from a mock provider.
     */
    @Suppress("DEPRECATION")
    fun isMockLocation(location: Location?): Boolean {
        if (location == null) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return location.isMock
        }
        return location.isFromMockProvider
    }
}
