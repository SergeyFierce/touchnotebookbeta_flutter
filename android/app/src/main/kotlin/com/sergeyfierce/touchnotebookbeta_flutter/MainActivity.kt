package com.sergeyfierce.touchnotebookbeta_flutter

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), ActivityCompat.OnRequestPermissionsResultCallback {

    companion object {
        private const val CHANNEL = "com.touchnotebookbeta/phone_permission"
        private const val REQUEST_PHONE_PERMISSION = 2001
    }

    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> handlePhonePermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handlePhonePermission(result: MethodChannel.Result) {
        if (permissionResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "Permission request is already running", null)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }

        val permissionState = ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
        if (permissionState == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        permissionResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CALL_PHONE), REQUEST_PHONE_PERMISSION)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != REQUEST_PHONE_PERMISSION) {
            return
        }

        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        permissionResult?.success(granted)
        permissionResult = null
    }
}
