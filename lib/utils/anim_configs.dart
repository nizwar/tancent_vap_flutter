import 'package:flutter/painting.dart';
import 'package:tancent_vap/utils/constant.dart';

/// Configuration data for VAP animations.
///
/// VAPConfigs contains all the technical details about a VAP animation file,
/// including dimensions, timing, orientation, and channel information.
/// This data is typically provided by the native VAP player when an animation
/// is loaded and ready to play.
///
/// The configuration is automatically parsed from native data and provided
/// through the [OnVideoConfigReady] callback.
///
/// Example usage:
/// ```dart
/// controller.setAnimListener(
///   onVideoConfigReady: (config) {
///     print('Animation size: ${config.width}x${config.height}');
///     print('FPS: ${config.fps}');
///     print('Total frames: ${config.totalFrames}');
///   },
/// );
/// ```
class VAPConfigs {
  /// The logical width of the animation in pixels.
  final int width;

  /// The logical height of the animation in pixels.
  final int height;

  /// Frames per second of the animation.
  final int fps;

  /// Total number of frames in the animation.
  final int totalFrames;

  /// Whether this is a mixed content animation (has both video and alpha channels).
  final bool isMix;

  /// The orientation of the video content.
  final VideoOrientation orien;

  /// The actual video height in pixels.
  final int videoHeight;

  /// The actual video width in pixels.
  final int videoWidth;

  /// Rectangle defining the alpha channel area in the video.
  /// Used for transparency information in mixed content animations.
  final Rect alphaPointRect;

  /// Rectangle defining the RGB channel area in the video.
  /// Contains the actual video content in mixed content animations.
  final Rect rgbPointRect;

  /// VAP format version number.
  final int version;

  /// Creates a VAPConfigs instance.
  ///
  /// All parameters are required as they represent essential animation properties.
  /// This constructor is typically not used directly - instead, use [VAPConfigs.fromMap]
  /// to create instances from native data.
  VAPConfigs({
    required this.width,
    required this.height,
    required this.fps,
    required this.totalFrames,
    required this.isMix,
    required this.orien,
    required this.videoHeight,
    required this.videoWidth,
    required this.alphaPointRect,
    required this.rgbPointRect,
    required this.version,
  });

  /// Creates a VAPConfigs instance from a map of native data.
  ///
  /// This factory constructor is used internally to parse configuration data
  /// received from the native VAP player. The map should contain all required
  /// fields with appropriate types.
  ///
  /// Parameters:
  /// - [json]: Map containing configuration data from native code
  ///
  /// Throws [TypeError] if required fields are missing or have wrong types.
  factory VAPConfigs.fromMap(Map<String, dynamic> json) {
    return VAPConfigs(
      width: json['width'] as int,
      height: json['height'] as int,
      fps: json['fps'] as int,
      totalFrames: json['totalFrames'] as int,
      videoHeight: json['videoHeight'] as int,
      videoWidth: json['videoWidth'] as int,
      isMix: json['isMix'] as bool,
      orien: VideoOrientation.fromValue(json['orien'] as int),
      alphaPointRect: Rect.fromLTRB(
        (json['alphaPointRect']["x"] as int).toDouble(),
        (json['alphaPointRect']["y"] as int).toDouble(),
        (json['alphaPointRect']["w"] as int).toDouble(),
        (json['alphaPointRect']["h"] as int).toDouble(),
      ),
      rgbPointRect: Rect.fromLTRB(
        (json['rgbPointRect']["x"] as int).toDouble(),
        (json['rgbPointRect']["y"] as int).toDouble(),
        (json['rgbPointRect']["w"] as int).toDouble(),
        (json['rgbPointRect']["h"] as int).toDouble(),
      ),
      version: json['version'] as int,
    );
  }

  /// Converts this VAPConfigs instance to a map.
  ///
  /// This method is primarily used for debugging and serialization purposes.
  /// The returned map contains all configuration properties with their current values.
  ///
  /// Returns a map with string keys and dynamic values representing the configuration.
  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'height': height,
      'fps': fps,
      'totalFrames': totalFrames,
      'isMix': isMix,
      'orien': orien,
      'videoHeight': videoHeight,
      'videoWidth': videoWidth,
      'alphaPointRect': alphaPointRect,
      'rgbPointRect': rgbPointRect,
      'version': version,
    };
  }
}
