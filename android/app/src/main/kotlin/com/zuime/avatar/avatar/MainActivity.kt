package com.zuime.avatar.avatar

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val channelName = "avatar.host"
    private var pickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> startPick()
                    "saveImage" -> saveImage(call, result)
                    "loadLocal" -> result.success(
                        getSharedPreferences("avatar_store", MODE_PRIVATE).all
                    )
                    "writeLocal" -> {
                        getSharedPreferences("avatar_store", MODE_PRIVATE).edit()
                            .putString(call.argument("key"), call.argument("value"))
                            .apply()
                        result.success(null)
                    }
                    "removeLocal" -> {
                        getSharedPreferences("avatar_store", MODE_PRIVATE).edit()
                            .remove(call.argument("key"))
                            .apply()
                        result.success(null)
                    }
                    "exitApp" -> runOnUiThread { finishAffinity() }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startPick() {
        val result = pickResult
        pickResult = null
        if (result == null) return
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        try {
            pickResult = result
            startActivityForResult(Intent.createChooser(intent, "选择图片"), 1001)
        } catch (e: Exception) {
            pickResult = null
            result.success(null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 1001) {
            val result = pickResult
            pickResult = null
            val uri = data?.data
            if (resultCode == RESULT_OK && uri != null && result != null) {
                try {
                    val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    result.success(bytes)
                } catch (e: Exception) {
                    result.success(null)
                }
            } else {
                result?.success(null)
            }
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun saveImage(call: MethodCall, result: MethodChannel.Result) {
        try {
            val bytes = call.argument<ByteArray>("bytes")
            val filename = call.argument<String>("name")
            if (bytes == null || filename == null) {
                result.success("保存失败：参数缺失")
                return
            }
            val msg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Avatar")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                if (uri == null) {
                    "保存失败，请重试"
                } else {
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                    "已保存到相册 Pictures/Avatar/$filename"
                }
            } else {
                val dir = File(getExternalFilesDir(Environment.DIRECTORY_PICTURES), "Avatar")
                dir.mkdirs()
                val file = File(dir, filename)
                FileOutputStream(file).use { it.write(bytes) }
                "已保存：${file.absolutePath}"
            }
            result.success(msg)
        } catch (e: Exception) {
            result.success("保存失败：${e.message ?: "未知错误"}")
        }
    }
}
