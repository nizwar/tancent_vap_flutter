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
    private val vapTagContents = mutableMapOf<String, String>()

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
        (params?.get("vapTagContents") as? Map<String, String>)?.let { contents ->
            vapTagContents.putAll(contents)
        }
        
        // Set the fetch resource callback to provide VAP tag contents
        animView.setFetchResource(object : IFetchResource {
            override fun fetchImage(resource: Resource, result: IFetchResource.Result) {
                val content = vapTagContents[resource.tag]
                if (content != null && content.isNotEmpty()) {
                    // For image resources, the content should be a file path or URL
                    // This is a simplified implementation - in a real app you might
                    // need to handle URLs, base64 images, etc.
                    try {
                        val bitmap = android.graphics.BitmapFactory.decodeFile(content)
                        if (bitmap != null) {
                            result.onSuccess(resource, bitmap)
                        } else {
                            result.onFailure(resource, RuntimeException("Failed to decode image: $content"))
                        }
                    } catch (e: Exception) {
                        result.onFailure(resource, e)
                    }
                } else {
                    result.onFailure(resource, RuntimeException("No content found for tag: ${resource.tag}"))
                }
            }

            override fun fetchText(resource: Resource, result: IFetchResource.Result) {
                val content = vapTagContents[resource.tag]
                if (content != null) {
                    result.onSuccess(resource, content)
                } else {
                    result.onFailure(resource, RuntimeException("No content found for tag: ${resource.tag}"))
                }
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
                val content = call.argument<String>("content")
                if (tag != null && content != null) {
                    setVapTagContent(tag, content)
                }
                result.success(null)
            }

            "setVapTagContents" -> {
                val contents = call.argument<Map<String, String>>("contents")
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
    private fun setVapTagContent(tag: String, content: String) {
        vapTagContents[tag] = content
    }

    private fun setVapTagContents(contents: Map<String, String>) {
        vapTagContents.putAll(contents)
    }

    private fun getVapTagContent(tag: String): String? {
        return vapTagContents[tag]
    }

    private fun clearVapTagContents() {
        vapTagContents.clear()
    }
}
