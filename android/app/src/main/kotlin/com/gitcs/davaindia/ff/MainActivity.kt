package com.gitcs.davaindia.ff

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/**
 * The self-updater's Android half (channel "ff/updater"): whether this app may install packages,
 * the setting to allow it, the SHA-256 of a downloaded APK, and handing the APK to the system installer.
 * Also makes the Alerts channel that pushes arrive on, and answers "ff/device" with the hardware ID.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertsChannel()
    }

    /**
     * Pushes go to this channel (the manifest makes it Firebase's default and the CRM names it). Without it
     * Firebase uses its own default-importance channel, which doesn't pop up. Creating it again is a no-op,
     * and once made the user's own settings for it win.
     */
    private fun createAlertsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel("alerts", "Alerts", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "New leads, approvals, payments and reminders"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The phone's hardware ID for sign-in blocking: Android ID, which stays the same across reinstalls of
        // this app and changes only on a factory reset. Apps can't read the MAC address on Android 10+.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ff/device").setMethodCallHandler { call, result ->
            if (call.method == "hardwareId") {
                result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ff/updater").setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "openInstallSettings" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "sha256" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path is required", null)
                    } else {
                        // Hashing a 60 MB file takes a moment: keep it off the UI thread.
                        Thread {
                            val hex = try { sha256(File(path)) } catch (e: Exception) { null }
                            runOnUiThread { result.success(hex) }
                        }.start()
                    }
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path is required", null)
                    } else {
                        try {
                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
                            startActivity(Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            })
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
