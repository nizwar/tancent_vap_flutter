import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tancent_vap/utils/constant.dart';

import '../utils/anim_configs.dart';

/// A widget that displays a video animation using the Vap library.
/// This widget supports both Android and iOS platforms and allows customization of video playback options such as
/// scale type, loop count, and mute state.
/// It also provides a controller to manage video playback and listen to various animation events.
class VapView extends StatefulWidget {
  final ScaleType scaleType;
  final int repeat;
  final bool mute;
  final Map<String, String>? vapTagContents;
  final Function(VapController)? onViewCreated;

  /// Creates a VapView widget.
  /// - `scaleType` specifies how the video should be scaled within the view.
  /// - `repeat` specifies the number of times the video should repeat (0 for no repeat, -1 for infinite loop).
  /// - `mute` specifies whether the video should be muted during playback.
  /// - `vapTagContents` specifies initial content for VAP tags (optional).
  /// - `onViewCreated` is a callback that provides the VapController once the view is created,
  /// allowing you to control video playback and listen to events.
  const VapView({super.key, this.scaleType = ScaleType.fitCenter, this.repeat = 0, this.mute = false, this.vapTagContents, this.onViewCreated});

  @override
  State<VapView> createState() => _VapViewState();
}

class _VapViewState extends State<VapView> {
  final VapController _controller = VapController();

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{'scaleType': widget.scaleType.key, 'loop': widget.repeat, 'mute': widget.mute};

    // Add VAP tag contents to creation params if provided
    if (widget.vapTagContents != null && widget.vapTagContents!.isNotEmpty) {
      creationParams['vapTagContents'] = widget.vapTagContents!;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(viewType: 'vap_view', creationParams: creationParams, creationParamsCodec: const StandardMessageCodec(), onPlatformViewCreated: _onPlatformViewCreated);
    } else {
      return AndroidView(viewType: 'vap_view', creationParams: creationParams, creationParamsCodec: const StandardMessageCodec(), onPlatformViewCreated: _onPlatformViewCreated);
    }
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('vap_view_$id');
    _controller._setChannel(channel);
    widget.onViewCreated?.call(_controller);
  }
}

class VapController {
  MethodChannel? _channel;

  MethodChannel get __channel {
    if (_channel == null) {
      throw Exception("Controller already disposed");
    }
    return _channel!;
  }

  OnFailed? _onFailed;
  OnVideoComplete? _onVideoComplete;
  OnVideoDestroy? _onVideoDestroy;
  OnVideoRender? _onVideoRender;
  OnVideoStart? _onVideoStart;
  OnVideoConfigReady? _onVideoConfigReady;

  void _setChannel(MethodChannel channel) {
    _channel = channel;
    _channel?.setMethodCallHandler((MethodCall call) => _handleNativeEvent(call));
  }

  /// Set the animation event listeners.
  /// This method allows you to set callbacks for various animation events such as failure, completion, destruction, rendering, start, and configuration readiness.
  /// Each callback can be null if you do not wish to handle that specific event.
  /// Example usage:
  /// ```dart
  /// controller.setAnimListener(
  ///   onFailed: (code, message) {
  ///     print("Animation failed with code $code: $message");
  ///   },
  ///   onVideoComplete: () {
  ///     print("Video playback completed");
  ///   },
  ///   onVideoDestroy: () {
  ///     print("Video destroyed");
  ///   },
  ///   onVideoRender: (frameIndex, config) {
  ///    print("Video rendered at frame $frameIndex with config: $config");
  ///   },
  ///   onVideoStart: () {
  ///    print("Video started");
  ///   },
  ///   onVideoConfigReady: (config) {
  ///    print("Video configuration is ready: $config");
  ///   },
  /// );
  /// ```
  ///
  /// This method should be called before playing any video to ensure that all events are captured.
  /// If you do not set a listener for a specific event, that event will be ignored.
  void setAnimListener({
    OnFailed? onFailed,
    OnVideoComplete? onVideoComplete,
    OnVideoDestroy? onVideoDestroy,
    OnVideoRender? onVideoRender,
    OnVideoStart? onVideoStart,
    OnVideoConfigReady? onVideoConfigReady,
  }) {
    _onFailed = onFailed;
    _onVideoComplete = onVideoComplete;
    _onVideoDestroy = onVideoDestroy;
    _onVideoRender = onVideoRender;
    _onVideoStart = onVideoStart;
    _onVideoConfigReady = onVideoConfigReady;
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'onFailed':
        if (_onFailed != null) {
          final code = call.arguments['errorCode'] as int;
          final type = call.arguments['errorType'] as String;
          final msg = call.arguments['errorMsg'] as String?;
          _onFailed!(code, type, msg);
        }
        break;
      case 'onVideoComplete':
        _onVideoComplete?.call();
        break;
      case 'onVideoDestroy':
        _onVideoDestroy?.call();
        break;
      case 'onVideoRender':
        final arguments = call.arguments;
        _onVideoRender?.call(arguments['frameIndex'], VAPConfigs.fromMap(Map.from(arguments['config'])));
        break;
      case 'onVideoStart':
        _onVideoStart?.call();
        break;
      case 'onVideoConfigReady':
        final arguments = call.arguments;
        _onVideoConfigReady?.call(VAPConfigs.fromMap(Map.from(arguments['config'])));
        break;
      default:
        throw UnimplementedError('Unhandled method: ${call.method}');
    }
  }

  /// Play video from a file path or asset.
  Future<void> playFile(String filePath) async {
    await __channel.invokeMethod('playFile', {'filePath': filePath});
  }

  /// Play video from an asset.
  /// The asset must be included in the pubspec.yaml file under the assets section.
  Future<void> playAsset(String assetName) async {
    await __channel.invokeMethod('playAsset', {'assetName': assetName});
  }

  /// Stop the video playback.
  /// This method will stop the video and reset the playback state.
  Future<void> stop() async {
    await __channel.invokeMethod('stop');
  }

  /// Set the loop count for the video playback.
  Future<void> setLoop(int loop) async {
    await __channel.invokeMethod('setLoop', {'loop': loop});
  }

  /// Set the mute state for the video playback.
  Future<void> setMute(bool mute) async {
    await __channel.invokeMethod('setMute', {'mute': mute});
  }

  /// Set the scale type for the video playback.
  Future<void> setScaleType(String scaleType) async {
    await __channel.invokeMethod('setScaleType', {'scaleType': scaleType});
  }

  /// Set content for a specific VAP tag.
  /// This allows you to provide dynamic content (like text or image URLs) that will be
  /// rendered in the VAP animation at runtime.
  ///
  /// Example:
  /// ```dart
  /// await controller.setVapTagContent('username', 'John Doe');
  /// await controller.setVapTagContent('avatar', 'https://example.com/avatar.jpg');
  /// ```
  Future<void> setVapTagContent(String tag, String content) async {
    await __channel.invokeMethod('setVapTagContent', {'tag': tag, 'content': content});
  }

  /// Set multiple VAP tag contents at once.
  /// This is more efficient than calling setVapTagContent multiple times.
  ///
  /// Example:
  /// ```dart
  /// await controller.setVapTagContents({
  ///   'username': 'John Doe',
  ///   'avatar': 'https://example.com/avatar.jpg',
  ///   'message': 'Hello World!'
  /// });
  /// ```
  Future<void> setVapTagContents(Map<String, String> contents) async {
    await __channel.invokeMethod('setVapTagContents', {'contents': contents});
  }

  /// Get content for a specific VAP tag.
  /// Returns null if the tag is not set.
  Future<String?> getVapTagContent(String tag) async {
    return await __channel.invokeMethod('getVapTagContent', {'tag': tag});
  }

  /// Get all VAP tag contents.
  /// Returns a map of all currently set tag contents.
  Future<Map<String, String>> getAllVapTagContents() async {
    final result = await __channel.invokeMethod('getAllVapTagContents');
    return Map<String, String>.from(result ?? {});
  }

  /// Dispose the controller and release resources.
  /// This method should be called when the controller is no longer needed.
  Future<void> dispose() async {
    try {
      await _channel?.invokeMethod('dispose');
    } catch (e) {
      // Ignore disposal errors
    } finally {
      _channel?.setMethodCallHandler(null);
      _channel = null;
    }
  }
}
