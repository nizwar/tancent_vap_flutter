import 'package:tancent_vap/utils/anim_configs.dart';

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

abstract class VAPContent {
  String get contentType;
  String get contentValue;

  Map<String, dynamic> get toMap {
    return {'contentType': contentType, 'contentValue': contentValue};
  }

  static VAPContent fromMap(Map<String, dynamic> value) {
    final contentType = value['contentType'] as String;
    final contentValue = value['contentValue'] as String;

    switch (contentType) {
      case 'text':
        return TextContent(contentValue);
      case 'image':
        if (contentValue.startsWith('http://') || contentValue.startsWith('https://')) {
          return ImageURLContent(contentValue);
        } else if (contentValue.startsWith('data:image/')) {
          return ImageBase64Content(contentValue);
        } else if (contentValue.startsWith('assets/')) {
          return ImageAssetContent(contentValue);
        } else {
          return ImageFileContent(contentValue);
        }
      default:
        throw ArgumentError('Unknown content type: $contentType');
    }
  }
}

class TextContent extends VAPContent {
  final String text;

  TextContent(this.text);

  @override
  String get contentType => 'text';

  @override
  String get contentValue => text;
}

class ImageBase64Content extends VAPContent {
  final String base64;

  ImageBase64Content(this.base64);

  @override
  String get contentType => 'image_base64';

  @override
  String get contentValue => base64;
}

class ImageFileContent extends VAPContent {
  final String filePath;

  ImageFileContent(this.filePath);

  @override
  String get contentType => 'image_file';

  @override
  String get contentValue => filePath;
}

class ImageAssetContent extends VAPContent {
  final String assetPath;

  ImageAssetContent(this.assetPath);

  @override
  String get contentType => 'image_asset';

  @override
  String get contentValue => assetPath;
}

class ImageURLContent extends VAPContent {
  final String url;

  ImageURLContent(this.url);

  @override
  String get contentType => 'image_url';

  @override
  String get contentValue => url;
}
