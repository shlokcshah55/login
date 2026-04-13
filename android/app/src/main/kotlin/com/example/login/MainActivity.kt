package com.srishlok.pinit

import android.os.Bundle
import com.mapbox.bindgen.Value
import com.mapbox.common.SettingsServiceFactory
import com.mapbox.common.SettingsServiceStorageType
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Opt out of Mapbox telemetry — Mapbox Maps SDK 11.x collects
        // anonymised location pings, device info, and session events by
        // default. Disable it before any MapView is constructed so no
        // events are queued.
        try {
            val result = SettingsServiceFactory
                .getInstance(SettingsServiceStorageType.PERSISTENT)
                .set("com.mapbox.telemetry.events.enabled", Value.valueOf(false))
            if (result.isValue) {
                println("✅ Mapbox telemetry disabled")
            } else {
                println("⚠️ Mapbox telemetry opt-out failed: ${result.error}")
            }
        } catch (e: Throwable) {
            println("⚠️ Mapbox telemetry opt-out threw: $e")
        }
    }
}
