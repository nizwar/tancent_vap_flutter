import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tancent_vap/utils/constant.dart';

import '../utils/anim_configs.dart';

/// A widget that displays Tencent VAP (Video Animation Player) animations.
///
/// VapView is a Flutter widget that renders VAP animations with support for:
/// - Multiple scale types (fitCenter, centerCrop, fitXY)
/// - Loop control (no repeat, finite repeats, infinite loop)
/// - Audio control (mute/unmute)
/// - Dynamic content injection via VAP tags
/// - Cross-platform support (iOS and Android)
///
/// The widget provides a [VapController] through the [onViewCreated] callback
/// for programmatic control of animation playback and content management.
///
/// Example usage:
/// ```dart
/// VapView(
///   scaleType: ScaleType.fitCenter,
///   repeat: -1, // Infinite loop
///   mute: false,
///   vapTagContents: {
///     'username': TextContent('John Doe'),
///     'avatar': ImageURLContent('https://example.com/avatar.jpg'),
///   },
///   onViewCreated: (controller) {
///     controller.setAnimListener(
///       onVideoStart: () => print('Animation started'),
///       onVideoComplete: () => print('Animation completed'),
///     );
///     controller.playAsset('animations/sample.mp4');
///   },
/// )
/// ```
class VapView extends StatefulWidget {
  /// How the video should be scaled within the view bounds.
  ///
  /// Defaults to [ScaleType.fitCenter].
  final ScaleType scaleType;

  /// Number of times the animation should repeat.
  ///
  /// - `0`: Play once (no repeat)
  /// - Positive number: Repeat that many times
  /// - `-1`: Infinite loop
  ///
  /// Defaults to `0`.
  final int repeat;

  /// Whether the animation should be muted during playback.
  ///
  /// Defaults to `false`.
  final bool mute;

  /// Initial dynamic content for VAP tags.
  ///
  /// This map allows you to provide content that will be injected into
  /// the VAP animation at runtime. Keys are tag names defined in the VAP file,
  /// values are [VAPContent] objects containing the actual content.
  ///
  /// Can be `null` if no initial content is needed.
  final Map<String, VAPContent>? vapTagContents;

  /// Callback invoked when the platform view is created.
  ///
  /// Provides a [VapController] instance that can be used to control
  /// animation playback, set content, and listen to events.
  ///
  /// This is the recommended way to obtain a controller reference.
  final Function(VapController)? onViewCreated;

  /// Creates a VapView widget.
  ///
  /// All parameters are optional and have sensible defaults:
  /// - [scaleType]: How to scale the video (defaults to [ScaleType.fitCenter])
  /// - [repeat]: Number of repetitions (defaults to 0 for no repeat)
  /// - [mute]: Whether to mute audio (defaults to false)
  /// - [vapTagContents]: Initial content for VAP tags (optional)
  /// - [onViewCreated]: Callback to receive the controller (optional)
  const VapView(
      {super.key,
      this.scaleType = ScaleType.fitCenter,
      this.repeat = 0,
      this.mute = false,
      this.vapTagContents,
      this.onViewCreated});

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
    final creationParams = <String, dynamic>{
      'scaleType': widget.scaleType.key,
      'loop': widget.repeat,
      'mute': widget.mute
    };

    // Add VAP tag contents to creation params if provided
    if (widget.vapTagContents != null && widget.vapTagContents!.isNotEmpty) {
      creationParams['vapTagContents'] = widget.vapTagContents!
          .map((key, value) => MapEntry(key, value.toMap));
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
          viewType: 'vap_view',
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated);
    } else {
      return AndroidView(
          viewType: 'vap_view',
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated);
    }
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('vap_view_$id');
    _controller._setChannel(channel);
    widget.onViewCreated?.call(_controller);
  }
}

/// Controller for programmatic management of VAP animations.
///
/// VapController provides methods to:
/// - Control playback (play, stop, loop settings)
/// - Manage dynamic content (set, get, clear VAP tag contents)
/// - Listen to animation events (start, complete, error, etc.)
/// - Configure playback settings (mute, scale type)
///
/// The controller is obtained through [VapView.onViewCreated] callback
/// and should be disposed when no longer needed to prevent memory leaks.
///
/// Example usage:
/// ```dart
/// VapController controller;
///
/// // Set event listeners
/// controller.setAnimListener(
///   onVideoStart: () => print('Started'),
///   onVideoComplete: () => print('Completed'),
///   onFailed: (code, type, msg) => print('Error: $code'),
/// );
///
/// // Play animation
/// await controller.playAsset('animations/sample.mp4');
///
/// // Set dynamic content
/// await controller.setVapTagContent('username', TextContent('John'));
///
/// // Clean up
/// controller.dispose();
/// ```
class VapController {
  /// Internal method channel for communication with native platforms.
  ///
  /// This channel is set when the platform view is created and is used
  /// for all communication between Dart and native code.
  MethodChannel? _channel;

  /// Gets the method channel, throwing an exception if the controller is disposed.
  ///
  /// Throws [Exception] if the controller has been disposed.
  MethodChannel get __channel {
    if (_channel == null) {
      throw Exception("Controller already disposed");
    }
    return _channel!;
  }

  /// Callback for animation failure events.
  OnFailed? _onFailed;

  /// Callback for animation completion events.
  OnVideoComplete? _onVideoComplete;

  /// Callback for animation destruction events.
  OnVideoDestroy? _onVideoDestroy;

  /// Callback for frame rendering events.
  OnVideoRender? _onVideoRender;

  /// Callback for animation start events.
  OnVideoStart? _onVideoStart;

  /// Callback for animation configuration ready events.
  OnVideoConfigReady? _onVideoConfigReady;

  /// Internal method to set the method channel.
  ///
  /// Called automatically when the platform view is created.
  /// Sets up the method call handler for receiving events from native code.
  void _setChannel(MethodChannel channel) {
    _channel = channel;
    _channel
        ?.setMethodCallHandler((MethodCall call) => _handleNativeEvent(call));
  }

  /// Sets event listeners for various animation events.
  ///
  /// All parameters are optional - only set listeners for events you need to handle.
  /// This method should typically be called before starting animation playback
  /// to ensure all events are captured.
  ///
  /// Parameters:
  /// - [onFailed]: Called when animation fails with error code, type, and message
  /// - [onVideoComplete]: Called when animation playback completes
  /// - [onVideoDestroy]: Called when animation is destroyed/cleaned up
  /// - [onVideoRender]: Called for each frame render with frame index and config
  /// - [onVideoStart]: Called when animation starts playing
  /// - [onVideoConfigReady]: Called when animation configuration is loaded
  ///
  /// Example:
  /// ```dart
  /// controller.setAnimListener(
  ///   onFailed: (code, type, message) {
  ///     print("Animation failed with code $code: $message");
  ///   },
  ///   onVideoComplete: () {
  ///     print("Video playback completed");
  ///   },
  ///   onVideoStart: () {
  ///     print("Video started");
  ///   },
  /// );
  /// ```
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

  /// Internal method to handle events from native platforms.
  ///
  /// Automatically routes native events to the appropriate Dart callbacks
  /// that were set via [setAnimListener].
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
          _onVideoRender!(
              frameIndex, config != null ? VAPConfigs.fromMap(config) : null);
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

  /// Plays a VAP animation from a file path.
  ///
  /// The [filePath] should point to a valid VAP file accessible to the app.
  /// This is typically used for files downloaded to the device or copied
  /// to the app's documents directory.
  ///
  /// Throws an exception if the file cannot be found or played.
  ///
  /// Example:
  /// ```dart
  /// await controller.playFile('/path/to/animation.mp4');
  /// ```
  Future<void> playFile(String filePath) async {
    await __channel.invokeMethod('playFile', {'filePath': filePath});
  }

  /// Plays a VAP animation from a Flutter asset.
  ///
  /// The [assetName] should correspond to an asset declared in `pubspec.yaml`.
  /// This is the recommended way to bundle VAP animations with your app.
  ///
  /// Throws an exception if the asset cannot be found or played.
  ///
  /// Example:
  /// ```dart
  /// await controller.playAsset('assets/animations/sample.mp4');
  /// ```
  Future<void> playAsset(String assetName) async {
    await __channel.invokeMethod('playAsset', {'assetName': assetName});
  }

  /// Stops the current animation playback.
  ///
  /// This will immediately stop the animation and reset the playback state.
  /// The animation can be restarted by calling [playFile] or [playAsset] again.
  ///
  /// Example:
  /// ```dart
  /// await controller.stop();
  /// ```
  Future<void> stop() async {
    await __channel.invokeMethod('stop');
  }

  /// Sets the loop count for animation playback.
  ///
  /// Parameters:
  /// - [loop]: Number of times to repeat the animation
  ///   - `0`: Play once (no repeat)
  ///   - Positive number: Repeat that many times
  ///   - `-1`: Infinite loop
  ///
  /// Example:
  /// ```dart
  /// await controller.setLoop(-1); // Infinite loop
  /// await controller.setLoop(3);  // Play 3 times
  /// ```
  Future<void> setLoop(int loop) async {
    await __channel.invokeMethod('setLoop', {'loop': loop});
  }

  /// Sets the mute state for animation playback.
  ///
  /// Parameters:
  /// - [mute]: `true` to mute audio, `false` to enable audio
  ///
  /// Example:
  /// ```dart
  /// await controller.setMute(true);  // Mute audio
  /// await controller.setMute(false); // Enable audio
  /// ```
  Future<void> setMute(bool mute) async {
    await __channel.invokeMethod('setMute', {'mute': mute});
  }

  /// Sets the scale type for animation display.
  ///
  /// Parameters:
  /// - [scaleType]: How the animation should be scaled within its container
  ///   - `'fitCenter'`: Scale to fit within bounds, maintaining aspect ratio
  ///   - `'centerCrop'`: Scale to fill bounds, cropping excess, maintaining aspect ratio
  ///   - `'fitXY'`: Scale to exactly fill bounds, potentially distorting aspect ratio
  ///
  /// Example:
  /// ```dart
  /// await controller.setScaleType('centerCrop');
  /// ```
  Future<void> setScaleType(String scaleType) async {
    await __channel.invokeMethod('setScaleType', {'scaleType': scaleType});
  }

  /// Sets content for a specific VAP tag.
  ///
  /// VAP tags are placeholders in the animation file that can be replaced
  /// with dynamic content at runtime. This allows for personalized animations
  /// with user-specific data.
  ///
  /// Parameters:
  /// - [tag]: The tag name defined in the VAP file (cannot be empty)
  /// - [content]: The content to inject ([VAPContent] subclass)
  ///
  /// Throws [ArgumentError] if [tag] is empty.
  ///
  /// Example:
  /// ```dart
  /// await controller.setVapTagContent('username', TextContent('John Doe'));
  /// await controller.setVapTagContent('avatar', ImageURLContent('https://...'));
  /// ```
  Future<void> setVapTagContent(String tag, VAPContent content) async {
    if (tag.isEmpty) {
      throw ArgumentError('Tag cannot be empty');
    }
    await __channel.invokeMethod(
        'setVapTagContent', {'tag': tag, 'content': content.toMap});
  }

  /// Sets multiple VAP tag contents at once.
  ///
  /// This method is more efficient than calling [setVapTagContent] multiple times
  /// as it batches all updates in a single native call.
  ///
  /// Parameters:
  /// - [contents]: Map of tag names to content objects
  ///
  /// Throws [ArgumentError] if any tag name is empty.
  /// Returns immediately if [contents] is empty.
  ///
  /// Example:
  /// ```dart
  /// await controller.setVapTagContents({
  ///   'username': TextContent('John Doe'),
  ///   'avatar': ImageURLContent('https://example.com/avatar.jpg'),
  ///   'message': TextContent('Hello World!')
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

    await __channel.invokeMethod('setVapTagContents',
        {'contents': contents.map((key, value) => MapEntry(key, value.toMap))});
  }

  /// Gets the content for a specific VAP tag.
  ///
  /// Parameters:
  /// - [tag]: The tag name to retrieve content for (cannot be empty)
  ///
  /// Returns the [VAPContent] associated with the tag, or `null` if no content is set.
  /// Throws [ArgumentError] if [tag] is empty.
  ///
  /// Example:
  /// ```dart
  /// VAPContent? content = await controller.getVapTagContent('username');
  /// if (content is TextContent) {
  ///   print('Username: ${content.text}');
  /// }
  /// ```
  Future<VAPContent?> getVapTagContent(String tag) async {
    if (tag.isEmpty) {
      throw ArgumentError('Tag cannot be empty');
    }
    return await __channel
        .invokeMethod('getVapTagContent', {'tag': tag}).then((result) {
      if (result == null) return null;
      return VAPContent.fromMap(Map<String, dynamic>.from(result as Map));
    });
  }

  /// Gets all currently set VAP tag contents.
  ///
  /// Returns a map containing all tag names and their associated content.
  /// The map will be empty if no content has been set.
  ///
  /// Example:
  /// ```dart
  /// Map<String, VAPContent> allContents = await controller.getAllVapTagContents();
  /// for (final entry in allContents.entries) {
  ///   print('Tag ${entry.key}: ${entry.value.contentValue}');
  /// }
  /// ```
  Future<Map<String, VAPContent>> getAllVapTagContents() async {
    final result = await __channel.invokeMethod('getAllVapTagContents');
    return Map<String, VAPContent>.from((result ?? {}) as Map)
        .map((key, value) {
      return MapEntry(key, VAPContent.fromMap(value as Map<String, dynamic>));
    });
  }

  /// Clears all VAP tag contents.
  ///
  /// This removes all previously set tag content mappings.
  /// The animation will continue to play but without any dynamic content.
  ///
  /// Example:
  /// ```dart
  /// await controller.clearVapTagContents();
  /// ```
  Future<void> clearVapTagContents() async {
    await __channel.invokeMethod('clearVapTagContents');
  }

  /// Checks if a specific VAP tag has content set.
  ///
  /// Parameters:
  /// - [tag]: The tag name to check
  ///
  /// Returns `true` if content is set for the tag, `false` otherwise.
  /// Returns `false` if [tag] is empty.
  ///
  /// Example:
  /// ```dart
  /// if (await controller.hasVapTagContent('username')) {
  ///   print('Username content is set');
  /// }
  /// ```
  Future<bool> hasVapTagContent(String tag) async {
    if (tag.isEmpty) {
      return false;
    }
    final content = await getVapTagContent(tag);
    return content != null;
  }

  /// Removes content for a specific VAP tag.
  ///
  /// Parameters:
  /// - [tag]: The tag name to remove content for (cannot be empty)
  ///
  /// Throws [ArgumentError] if [tag] is empty.
  /// Has no effect if the tag doesn't have content set.
  ///
  /// Example:
  /// ```dart
  /// await controller.removeVapTagContent('username');
  /// ```
  Future<void> removeVapTagContent(String tag) async {
    if (tag.isEmpty) {
      throw ArgumentError('Tag cannot be empty');
    }

    final allContents = await getAllVapTagContents();
    allContents.remove(tag);
    await setVapTagContents(allContents);
  }

  /// Checks if the controller has been disposed.
  ///
  /// Returns `true` if [dispose] has been called, `false` otherwise.
  /// A disposed controller cannot be used for any operations.
  bool get isDisposed => _channel == null;

  /// Disposes the controller and releases associated resources.
  ///
  /// This method should be called when the controller is no longer needed
  /// to prevent memory leaks. After calling this method, the controller
  /// cannot be used for any operations.
  ///
  /// It's safe to call this method multiple times.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   controller.dispose();
  ///   super.dispose();
  /// }
  /// ```
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
