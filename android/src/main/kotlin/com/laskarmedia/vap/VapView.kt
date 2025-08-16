package com.laskarmedia.vap

import android.content.Context
import android.graphics.Bitmap
import android.view.View
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import android.os.Handler
import android.os.Looper
import android.widget.FrameLayout
import android.util.Log
import androidx.annotation.IntegerRes
import com.tencent.qgame.animplayer.AnimConfig
import com.tencent.qgame.animplayer.AnimView
import com.tencent.qgame.animplayer.inter.IAnimListener
import com.tencent.qgame.animplayer.inter.IFetchResource
import com.tencent.qgame.animplayer.mix.Resource
import com.tencent.qgame.animplayer.util.ScaleType
import org.json.JSONObject

// import com.tencent.vap.player.AnimView // Uncomment when VAP is available

import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

class VapViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val params = args as? Map<String, Any?>
        return VapView(context, params, messenger, id)
    }
}

@OptIn(DelicateCoroutinesApi::class)
class VapView(
    context: Context, params: Map<String, Any?>?, messenger: BinaryMessenger, id: Int
) : PlatformView, MethodChannel.MethodCallHandler {
    private val frameLayout = FrameLayout(context)
    private val animView = AnimView(context)
    private val channel = MethodChannel(messenger, "vap_view_$id")
    private var playResult: MethodChannel.Result? = null
    private val vapTagContents = mutableMapOf<String, Map<String, String>>()

    init {
        // Set scaleType from params
        when (params?.get("scaleType") as? String) {
            "fitCenter" -> animView.setScaleType(ScaleType.FIT_CENTER)
            "centerCrop" -> animView.setScaleType(ScaleType.CENTER_CROP)
            "fitXY" -> animView.setScaleType(ScaleType.FIT_XY)
            else -> animView.setScaleType(ScaleType.FIT_CENTER)
        }

        channel.setMethodCallHandler(this)
        frameLayout.addView(animView)

        // Initial playback if filePath or assetName is provided
        (params?.get("filePath") as? String)?.let { playFile(it, null) }
        (params?.get("assetName") as? String)?.let { playAsset(it, context, null) }
        (params?.get("loop") as? Int)?.let { animView.setLoop(it) }
        (params?.get("mute") as? Boolean)?.let { animView.setMute(it) }
        
        // Set initial VAP tag contents from params
        (params?.get("vapTagContents") as? Map<String, Map<String, String>>)?.let { contents ->
            for ((tag, contentMap) in contents) {
                vapTagContents[tag] = contentMap
                Log.d("VapView", "Stored tag content for tag: $tag, contentType: ${contentMap["contentType"]} contentValue: ${contentMap["contentValue"]}")
            }
        }
        
        // Set the fetch resource callback to provide VAP tag contents
        animView.setFetchResource(object : IFetchResource {
            override fun fetchImage(resource: Resource, result: (Bitmap?) -> Unit) {
                val contentMap = vapTagContents[resource.tag]
                val contentValue = contentMap?.get("contentValue")
                val contentType = contentMap?.get("contentType")
                
                if (!contentValue.isNullOrEmpty() && !contentType.isNullOrEmpty()) {
                    handleVapTagContent(contentValue, contentType, resource.tag) { bitmap ->
                        result(bitmap)
                    }
                } else {
                    Log.w("VapView", "No content found for tag: ${resource.tag}")
                    result(null)
                }
            }

            override fun fetchText(resource: Resource, result: (String?) -> Unit) {
                val contentMap = vapTagContents.get(resource.tag)
                val contentValue = contentMap?.get("contentValue")
                result(contentValue)
            }

            override fun releaseResource(resources: List<Resource>) {
                // Don't clear vapTagContents here as they might be reused
                // vapTagContents.clear()
            }
        })
        animView.setAnimListener(object : IAnimListener {
            override fun onVideoConfigReady(config: AnimConfig): Boolean {
                GlobalScope.launch(Dispatchers.Main) {
                    val animConfigMap = mutableMapOf<String, Any>()
                    config.let {
                        animConfigMap["width"] = it.width
                        animConfigMap["height"] = it.height
                        animConfigMap["fps"] = it.fps
                        animConfigMap["totalFrames"] = it.totalFrames
                        animConfigMap["videoHeight"] = it.videoHeight
                        animConfigMap["videoWidth"] = it.videoWidth
                        animConfigMap["isMix"] = it.isMix
                        animConfigMap["orien"] = it.orien
                        animConfigMap["alphaPointRect"] = mapOf(
                            "x" to it.alphaPointRect.x,
                            "y" to it.alphaPointRect.y,
                            "w" to it.alphaPointRect.w,
                            "h" to it.alphaPointRect.h
                        )
                        animConfigMap["rgbPointRect"] = mapOf(
                            "x" to it.rgbPointRect.x,
                            "y" to it.rgbPointRect.y,
                            "w" to it.rgbPointRect.w,
                            "h" to it.rgbPointRect.h
                        )
                        animConfigMap["version"] = it.version
                    }
                    val args = mapOf(
                        "config" to animConfigMap
                    )
                    channel.invokeMethod("onVideoConfigReady", args)
                }
                return super.onVideoConfigReady(config)
            }

            override fun onFailed(errorType: Int, errorMsg: String?) {
                playError(errorType, errorMsg)
                val args = mapOf("errorCode" to errorType, "errorMsg" to errorMsg, "errorType" to "VIDEO_PLAYBACK_ERROR")
                channel.invokeMethod("onFailed", args)
            }

            override fun onVideoComplete() {
                GlobalScope.launch(Dispatchers.Main) {
                   playSuccess()
                    channel.invokeMethod("onVideoComplete", null)
                }
            }

            override fun onVideoDestroy() {
                GlobalScope.launch(Dispatchers.Main) {
                    channel.invokeMethod("onVideoDestroy", null)
                }
            }

            override fun onVideoRender(frameIndex: Int, config: AnimConfig?) {
                GlobalScope.launch(Dispatchers.Main) {
                    val animConfigMap = mutableMapOf<String, Any>()
                    config?.let {
                        animConfigMap["width"] = it.width
                        animConfigMap["height"] = it.height
                        animConfigMap["fps"] = it.fps
                        animConfigMap["totalFrames"] = it.totalFrames
                        animConfigMap["videoHeight"] = it.videoHeight
                        animConfigMap["videoWidth"] = it.videoWidth
                        animConfigMap["isMix"] = it.isMix
                        animConfigMap["orien"] = it.orien
                        animConfigMap["alphaPointRect"] = mapOf(
                            "x" to it.alphaPointRect.x,
                            "y" to it.alphaPointRect.y,
                            "w" to it.alphaPointRect.w,
                            "h" to it.alphaPointRect.h
                        )
                        animConfigMap["rgbPointRect"] = mapOf(
                            "x" to it.rgbPointRect.x,
                            "y" to it.rgbPointRect.y,
                            "w" to it.rgbPointRect.w,
                            "h" to it.rgbPointRect.h
                        )
                        animConfigMap["version"] = it.version
                    }
                    val args = mapOf(
                        "frameIndex" to frameIndex, "config" to animConfigMap
                    )
                    channel.invokeMethod("onVideoRender", args)
                }
            }

            override fun onVideoStart() {
                GlobalScope.launch(Dispatchers.Main) {
                    channel.invokeMethod("onVideoStart", null)
                }
            }
        })
    }

    override fun getView(): View = frameLayout

    private fun playError(errorType: Int, errorMsg: String?) {
        if (playResult != null) {
            playResult?.error(errorType.toString(), errorMsg, "$errorType: VIDEO_PLAYBACK_ERROR")
            playResult = null
        }
    }

    private fun playSuccess() {
        if (playResult != null) {
            playResult?.success(null)
            playResult = null
        }
    }

    private fun reset() {
        animView.stopPlay()
        frameLayout.removeAllViews()
    }

    override fun dispose() {
        this.reset()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dispose" -> {
                dispose()
            }

            "playFile" -> {
                val path = call.argument<String>("filePath")
                playFile(path, result)
            }

            "playAsset" -> {
                val asset = call.argument<String>("assetName")
                playAsset(asset, frameLayout.context, result)
            }

            "stop" -> {
                animView.stopPlay()
                result.success(null)
            }

            "setLoop" -> {
                val loop = call.argument<Int>("loop") ?: 1
                animView.setLoop(loop)
                result.success(null)
            }

            "setMute" -> {
                val mute = call.argument<Boolean>("mute") ?: false
                animView.setMute(mute)
                result.success(null)
            }

            "setScaleType" -> {
                val type = call.argument<String>("scaleType")
                setScaleType(type)
                result.success(null)
            }

            "setVapTagContent" -> {
                val tag = call.argument<String>("tag")
                val contentMap = call.argument<Map<String, String>>("content")
                if (tag != null && contentMap != null) {
                    setVapTagContent(tag, contentMap)
                }
                result.success(null)
            }

            "setVapTagContents" -> {
                val contents = call.argument<Map<String, Map<String, String>>>("contents")
                if (contents != null) {
                    setVapTagContents(contents)
                }
                result.success(null)
            }

            "getVapTagContent" -> {
                val tag = call.argument<String>("tag")
                val content = if (tag != null) getVapTagContent(tag) else null
                result.success(content)
            }

            "getAllVapTagContents" -> {
                result.success(vapTagContents.toMap())
            }

            else -> result.notImplemented()
        }
    }

    private fun playFile(path: String?, result: MethodChannel.Result?) {
        if (path != null) {
            playResult = result
            animView.startPlay(java.io.File(path))
        }
    }

    private fun playAsset(asset: String?, context: Context, result: MethodChannel.Result?) {
        if (asset != null) {
            playResult = result
            animView.startPlay(context.assets, "flutter_assets/$asset")
        }
    }

    private fun setScaleType(type: String?) {
        when (type) {
            "fitCenter" -> animView.setScaleType(ScaleType.FIT_CENTER)
            "centerCrop" -> animView.setScaleType(ScaleType.CENTER_CROP)
            "fitXY" -> animView.setScaleType(ScaleType.FIT_XY)
            else -> animView.setScaleType(ScaleType.FIT_CENTER)
        }
    }

    // VAP Tag Content Management
    private fun setVapTagContent(tag: String, contentMap: Map<String, String>) {
        vapTagContents[tag] = contentMap
    }

    private fun setVapTagContents(contents: Map<String, Map<String, String>>) {
        vapTagContents.putAll(contents)
    }

    private fun getVapTagContent(tag: String): String? {
        return vapTagContents[tag]?.get("contentValue")
    }

    private fun clearVapTagContents() {
        vapTagContents.clear()
    }

        // Handle VAP tag content - supports different content types
        private fun handleVapTagContent(content: String, contentType: String, tag: String, callback: (Bitmap?) -> Unit) {
            Log.d("VapView", "Processing tag: $tag, contentType: $contentType")
            
            try {
                when (contentType) {
                    "image_base64" -> {
                        handleBase64Image(content, tag, callback)
                    }
                    "image_file" -> {
                        handleFileImage(content, tag, callback)
                    }
                    "image_asset" -> {
                        handleAssetImage(content, tag, callback)
                    }
                    "image_url" -> {
                        handleUrlImage(content, tag, callback)
                    }
                    "text" -> {
                        // Text content is not handled by image loading, skip
                        Log.d("VapView", "Text content type for tag: $tag, skipping image loading")
                        callback(null)
                    }
                    else -> {
                        Log.e("VapView", "Unsupported content type: $contentType for tag: $tag")
                        callback(null)
                    }
                }
            } catch (e: Exception) {
                Log.e("VapView", "Error handling VAP tag content for tag '$tag': ${e.message}")
                callback(null)
            }
        }

        private fun handleBase64Image(content: String, tag: String, callback: (Bitmap?) -> Unit) {
            GlobalScope.launch(Dispatchers.IO) {
                try {
                    var base64String = content
                    
                    // Remove data URL prefix if present (e.g., "data:image/png;base64,")
                    when {
                        content.startsWith("data:image/") -> {
                            val commaIndex = content.indexOf(",")
                            if (commaIndex != -1) {
                                base64String = content.substring(commaIndex + 1)
                            }
                        }
                        content.startsWith("base64:") -> {
                            base64String = content.substring(7) // Remove "base64:" prefix
                        }
                    }
                    
                    val byteArray = android.util.Base64.decode(base64String, android.util.Base64.DEFAULT)
                    val bitmap = android.graphics.BitmapFactory.decodeByteArray(byteArray, 0, byteArray.size)
                    
                    GlobalScope.launch(Dispatchers.Main) {
                        if (bitmap != null) {
                            Log.d("VapView", "Successfully decoded base64 image for tag: $tag")
                        } else {
                            Log.e("VapView", "Failed to decode base64 image for tag: $tag")
                        }
                        callback(bitmap)
                    }
                } catch (e: Exception) {
                    Log.e("VapView", "Error decoding base64 image for tag '$tag': ${e.message}")
                    GlobalScope.launch(Dispatchers.Main) {
                        callback(null)
                    }
                }
            }
        }

        private fun handleFileImage(filePath: String, tag: String, callback: (Bitmap?) -> Unit) {
            GlobalScope.launch(Dispatchers.IO) {
                try {
                    var fullPath = filePath
                    
                    // Handle different file path types
                    when {
                        filePath.startsWith("/") -> {
                            // Absolute path
                            fullPath = filePath
                        }
                        filePath.startsWith("file://") -> {
                            // File URL
                            fullPath = filePath.substring(7)
                        }
                        else -> {
                            // Relative path - try in different locations
                            val context = frameLayout.context
                            
                            // Try in external files dir
                            val externalFile = java.io.File(context.getExternalFilesDir(null), filePath)
                            if (externalFile.exists()) {
                                fullPath = externalFile.absolutePath
                            } else {
                                // Try in internal files dir
                                val internalFile = java.io.File(context.filesDir, filePath)
                                if (internalFile.exists()) {
                                    fullPath = internalFile.absolutePath
                                } else {
                                    // Use as-is and let it fail if invalid
                                    fullPath = filePath
                                }
                            }
                        }
                    }
                    
                    val file = java.io.File(fullPath)
                    if (!file.exists()) {
                        Log.e("VapView", "File not found: $fullPath for tag: $tag")
                        GlobalScope.launch(Dispatchers.Main) {
                            callback(null)
                        }
                        return@launch
                    }
                    
                    val bitmap = android.graphics.BitmapFactory.decodeFile(fullPath)
                    GlobalScope.launch(Dispatchers.Main) {
                        if (bitmap != null) {
                            Log.d("VapView", "Successfully loaded file image for tag: $tag from: $fullPath")
                        } else {
                            Log.e("VapView", "Failed to decode image file: $fullPath for tag: $tag")
                        }
                        callback(bitmap)
                    }
                } catch (e: Exception) {
                    Log.e("VapView", "Error loading file image for tag '$tag': ${e.message}")
                    GlobalScope.launch(Dispatchers.Main) {
                        callback(null)
                    }
                }
            }
        }

        private fun handleAssetImage(assetPath: String, tag: String, callback: (Bitmap?) -> Unit) {
            GlobalScope.launch(Dispatchers.IO) {
                try {
                    val context = frameLayout.context
                    val inputStream = context.assets.open("flutter_assets/$assetPath")
                    val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                    inputStream.close()
                    
                    GlobalScope.launch(Dispatchers.Main) {
                        if (bitmap != null) {
                            Log.d("VapView", "Successfully loaded asset image for tag: $tag from: $assetPath")
                        } else {
                            Log.e("VapView", "Failed to decode asset image: $assetPath for tag: $tag")
                        }
                        callback(bitmap)
                    }
                } catch (e: Exception) {
                    Log.e("VapView", "Error loading asset image for tag '$tag': ${e.message}")
                    GlobalScope.launch(Dispatchers.Main) {
                        callback(null)
                    }
                }
            }
        }

        private fun handleUrlImage(url: String, tag: String, callback: (Bitmap?) -> Unit) {
            GlobalScope.launch(Dispatchers.IO) {
                try {
                    val connection = java.net.URL(url).openConnection()
                    connection.doInput = true
                    connection.connect()
                    val inputStream = connection.getInputStream()
                    val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                    inputStream.close()
                    
                    GlobalScope.launch(Dispatchers.Main) {
                        if (bitmap != null) {
                            Log.d("VapView", "Successfully loaded URL image for tag: $tag from: $url")
                        } else {
                            Log.e("VapView", "Failed to decode URL image: $url for tag: $tag")
                        }
                        callback(bitmap)
                    }
                } catch (e: Exception) {
                    Log.e("VapView", "Error loading URL image for tag '$tag': ${e.message}")
                    GlobalScope.launch(Dispatchers.Main) {
                        callback(null)
                    }
                }
            }
        }
}
