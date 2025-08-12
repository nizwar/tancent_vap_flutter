import 'package:vap/utils/anim_configs.dart';

/// ScaleType for video scaling options
/// This enum defines how the video should be scaled within its container.
/// - `fitCenter`: Scales the video to fit within the container while maintaining its aspect ratio.
/// - `centerCrop`: Scales the video to fill the container, cropping any excess parts while maintaining its aspect ratio.
/// - `fitXY`: Scales the video to fit exactly within the
enum ScaleType {
  fitCenter("fitCenter"),
  centerCrop("centerCrop"),
  fitXY("fitXY");

  final String key;

  const ScaleType(this.key);
}

/// VideoOrientation for video orientation options
/// This enum defines the orientation of the video.
/// - `none`: No specific orientation.
/// - `portrait`: The video is in portrait mode.
/// - `landscape`: The video is in landscape mode.
/// Use `VideoOrientation.fromValue(int value)` to convert an integer value to a `VideoOrientation`.
/// The integer values are:
/// - `0`: none
/// - `1`: portrait
/// - `2`: landscape
///
/// If the value does not match any of these, it defaults to `none`.
enum VideoOrientation {
  none(0),
  portrait(1),
  landscape(2);

  final int value;

  const VideoOrientation(this.value);

  static VideoOrientation fromValue(int value) {
    return VideoOrientation.values.firstWhere((e) => e.value == value, orElse: () => none);
  }
}

/// Callback when the video view is created
typedef OnFailed = void Function(int code, String type, String? message);

/// Callback when the video is ready to play
typedef OnVideoComplete = void Function();

/// Callback when the video is destroyed
typedef OnVideoDestroy = void Function();

/// Configs only available on Android
typedef OnVideoRender = void Function(int frameInfo, VAPConfigs? configs);

/// Callback when the video configuration is ready
typedef OnVideoConfigReady = void Function(VAPConfigs configs);

/// Callback when the video starts playing
typedef OnVideoStart = void Function();
