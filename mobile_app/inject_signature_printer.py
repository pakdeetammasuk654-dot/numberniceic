
import os

# Updated MainActivity.kt with MethodChannel to retrieve Signature
kotlin_code = '''package com.taya.numberniceic

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.content.pm.Signature
import java.security.MessageDigest
import android.util.Base64
import android.os.Build

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.taya.numberniceic/info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSignature") {
                val signature = getAppSignature()
                result.success(signature)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getAppSignature(): String {
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo.apkContentsSigners
            } else {
                packageInfo.signatures
            }

            for (signature in signatures) {
                val md = MessageDigest.getInstance("SHA1")
                md.update(signature.toByteArray())
                val digest = md.digest()
                // Convert to Hex with Colon
                val hexString = StringBuilder()
                for (b in digest) {
                    hexString.append(String.format("%02X:", b))
                }
                if (hexString.length > 0) {
                    hexString.setLength(hexString.length - 1)
                }
                return hexString.toString()
            }
        } catch (e: Exception) {
            return "Error: " + e.message
        }
        return "No Signature Found"
    }
}
'''

file_path = 'android/app/src/main/kotlin/com/taya/numberniceic/MainActivity.kt'
# Ensure directory exists (it should, we moved it)
os.makedirs(os.path.dirname(file_path), exist_ok=True)

with open(file_path, 'w') as f:
    f.write(kotlin_code)

print("Updated MainActivity.kt with Signature Printer logic.")
