
import os

# Updated MainActivity.kt to redirect packageName as well
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
            } else if (call.method == "getPackageName") {
                result.success(packageName)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getAppSignature(): String {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                val signingInfo = packageInfo.signingInfo
                
                if (signingInfo == null) return "No Signing Info"
                
                val signatures = if (signingInfo.hasMultipleSigners()) {
                    signingInfo.apkContentsSigners
                } else {
                    signingInfo.signingCertificateHistory
                }
                
                if (signatures != null && signatures.isNotEmpty()) {
                   return hashSignature(signatures[0])
                }
            } else {
                val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                val signatures = packageInfo.signatures
                if (signatures != null && signatures.isNotEmpty()) {
                    return hashSignature(signatures[0])
                }
            }
        } catch (e: Exception) {
            return "Error: " + e.message
        }
        return "No Signature Found"
    }

    private fun hashSignature(signature: Signature): String {
        val md = MessageDigest.getInstance("SHA1")
        md.update(signature.toByteArray())
        val digest = md.digest()
        val hexString = StringBuilder()
        for (b in digest) {
            hexString.append(String.format("%02X:", b))
        }
        if (hexString.length > 0) {
            hexString.setLength(hexString.length - 1)
        }
        return hexString.toString()
    }
}
'''

file_path = 'android/app/src/main/kotlin/com/taya/numberniceic/MainActivity.kt'
with open(file_path, 'w') as f:
    f.write(kotlin_code)
print("Updated MainActivity.kt with packageName getter.")
