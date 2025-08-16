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
  final Map<String, VAPContent>? vapTagContents;
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
  void dispose() {
    // Dispose the controller when the widget is disposed
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{'scaleType': widget.scaleType.key, 'loop': widget.repeat, 'mute': widget.mute};

    // Add VAP tag contents to creation params if provided
    if (widget.vapTagContents != null && widget.vapTagContents!.isNotEmpty) {
      creationParams['vapTagContents'] = widget.vapTagContents!.map((key, value) => MapEntry(key, value.toMap));
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
          final args = call.arguments as Map<String, dynamic>;
          final code = args['errorCode'] as int;
          final type = args['errorType'] as String;
          final msg = args['errorMsg'] as String?;
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
        if (_onVideoRender != null) {
          final args = call.arguments as Map<String, dynamic>;
          final frameIndex = args['frameIndex'] as int;
          final config = args['config'] as Map<String, dynamic>?;
          _onVideoRender!(frameIndex, config != null ? VAPConfigs.fromMap(config) : null);
        }
        break;
      case 'onVideoStart':
        _onVideoStart?.call();
        break;
      case 'onVideoConfigReady':
        if (_onVideoConfigReady != null) {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final config = Map<String, dynamic>.from(args['config'] as Map);
          _onVideoConfigReady!(VAPConfigs.fromMap(config));
        }
        break;
      default:
        throw UnimplementedError('Unhandled method: ${call.method}');
    }
  }

  /// Play video from a file path.
  /// The filePath should point to a valid VAP file on the device.
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
  /// Use 0 for no repeat, -1 for infinite loop, or a positive number for specific repeat count.
  Future<void> setLoop(int loop) async {
    await __channel.invokeMethod('setLoop', {'loop': loop});
  }

  /// Set the mute state for the video playback.
  Future<void> setMute(bool mute) async {
    await __channel.invokeMethod('setMute', {'mute': mute});
  }

  /// Set the scale type for the video playback.
  /// Available options: 'fitCenter', 'centerCrop', 'fitXY'
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
  /// await controller.setVapTagContent('avatar', '/path/to/avatar.jpg');
  /// ```
  Future<void> setVapTagContent(String tag, VAPContent content) async {
    if (tag.isEmpty) {
      throw ArgumentError('Tag cannot be empty');
    }
    await __channel.invokeMethod('setVapTagContent', {'tag': tag, 'content': content.toMap});
  }

  /// Set multiple VAP tag contents at once.
  /// This is more efficient than calling setVapTagContent multiple times.
  ///
  /// Example:
  /// ```dart
  /// await controller.setVapTagContents({
  ///   'username': 'John Doe',
  ///   'avatar': '/path/to/avatar.jpg',
  ///   'message': 'Hello World!'
  /// });
  /// ```
  Future<void> setVapTagContents(Map<String, VAPContent> contents) async {
    if (contents.isEmpty) {
      return; // Nothing to set
    }

    // Validate that no tags are empty
    for (final tag in contents.keys) {
      if (tag.isEmpty) {
        throw ArgumentError('Tag cannot be empty');
      }
    }

    await __channel.invokeMethod('setVapTagContents', {'contents': contents.map((key, value) => MapEntry(key, value.toMap))});
  }

  /// Get content for a specific VAP tag.
  /// Returns null if the tag is not set.
  Future<VAPContent?> getVapTagContent(String tag) async {
    if (tag.isEmpty) {
      throw ArgumentError('Tag cannot be empty');
    }
    return await __channel.invokeMethod('getVapTagContent', {'tag': tag}).then((result) {
      if (result == null) return null;
      return VAPContent.fromMap(Map<String, dynamic>.from(result as Map));
    });
  }

  /// Get all VAP tag contents.
  /// Returns a map of all currently set tag contents.
  Future<Map<String, VAPContent>> getAllVapTagContents() async {
    final result = await __channel.invokeMethod('getAllVapTagContents');
    return Map<String, VAPContent>.from((result ?? {}) as Map).map((key, value) {
      return MapEntry(key, VAPContent.fromMap(value as Map<String, dynamic>));
    });
  }

  /// Clear all VAP tag contents.
  /// This removes all previously set tag content mappings.
  Future<void> clearVapTagContents() async {
    await __channel.invokeMethod('setVapTagContents', {'contents': <String, String>{}});
  }

  /// Check if a specific VAP tag has content set.
  Future<bool> hasVapTagContent(String tag) async {
    if (tag.isEmpty) {
      return false;
    }
    final content = await getVapTagContent(tag);
    return content != null;
  }

  /// Remove content for a specific VAP tag.
  Future<void> removeVapTagContent(String tag) async {
    if (tag.isEmpty) {
      throw ArgumentError('Tag cannot be empty');
    }

    final allContents = await getAllVapTagContents();
    allContents.remove(tag);
    await setVapTagContents(allContents);
  }

  /// Check if the controller is disposed.
  bool get isDisposed => _channel == null;

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
