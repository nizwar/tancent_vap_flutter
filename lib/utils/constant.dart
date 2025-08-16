import 'package:tancent_vap/utils/anim_configs.dart';

/// Defines how video content should be scaled within its container.
///
/// These scale types determine how the VAP animation is displayed when the
/// animation dimensions don't exactly match the widget size.
///
/// Example usage:
/// ```dart
/// VapView(
///   scaleType: ScaleType.fitCenter, // Maintain aspect ratio, fit within bounds
/// )
/// ```
enum ScaleType {
  /// Scales the video to fit within the container while maintaining aspect ratio.
  /// The entire video will be visible, but there may be empty space if the
  /// aspect ratios don't match.
  fitCenter("fitCenter"),

  /// Scales the video to fill the container while maintaining aspect ratio.
  /// The video may be cropped if aspect ratios don't match, but no empty space
  /// will be visible.
  centerCrop("centerCrop"),

  /// Scales the video to exactly fill the container bounds.
  /// This may distort the video if aspect ratios don't match, but ensures
  /// the entire container is filled.
  fitXY("fitXY");

  /// The string key used for native platform communication.
  final String key;

  const ScaleType(this.key);
}

/// Defines the orientation of video content.
///
/// This enum represents the orientation metadata of the VAP animation,
/// which can be used to determine how the content should be displayed
/// or processed.
enum VideoOrientation {
  /// No specific orientation or orientation is unknown.
  none(0),

  /// Video content is in portrait orientation (height > width).
  portrait(1),

  /// Video content is in landscape orientation (width > height).
  landscape(2);

  /// The integer value used for native platform communication.
  final int value;

  const VideoOrientation(this.value);

  /// Creates a VideoOrientation from an integer value.
  ///
  /// This method is used when parsing orientation data from native platforms.
  /// If the provided [value] doesn't match any known orientation, returns [none].
  ///
  /// Parameters:
  /// - [value]: Integer value representing the orientation (0=none, 1=portrait, 2=landscape)
  static VideoOrientation fromValue(int value) {
    return VideoOrientation.values.firstWhere((e) => e.value == value, orElse: () => none);
  }
}

/// Callback function for animation failure events.
///
/// Called when an animation fails to load or play.
///
/// Parameters:
/// - [code]: Error code indicating the type of failure
/// - [type]: String description of the error type
/// - [message]: Optional detailed error message
typedef OnFailed = void Function(int code, String type, String? message);

/// Callback function for animation completion events.
///
/// Called when an animation finishes playing completely.
typedef OnVideoComplete = void Function();

/// Callback function for animation destruction events.
///
/// Called when an animation is destroyed and resources are cleaned up.
typedef OnVideoDestroy = void Function();

/// Callback function for frame rendering events.
///
/// Called for each frame that is rendered during animation playback.
/// This callback is only available on Android.
///
/// Parameters:
/// - [frameInfo]: Index of the current frame being rendered
/// - [configs]: Animation configuration data (may be null)
typedef OnVideoRender = void Function(int frameInfo, VAPConfigs? configs);

/// Callback function for animation configuration ready events.
///
/// Called when the animation file has been loaded and configuration
/// data is available.
///
/// Parameters:
/// - [configs]: Complete animation configuration data
typedef OnVideoConfigReady = void Function(VAPConfigs configs);

/// Callback function for animation start events.
///
/// Called when an animation begins playing.
typedef OnVideoStart = void Function();

/// Abstract base class for dynamic content that can be injected into VAP animations.
///
/// VAPContent represents different types of content (text, images) that can be
/// dynamically inserted into VAP animations at runtime. This allows for
/// personalized animations with user-specific data.
///
/// Subclasses include:
/// - [TextContent]: For dynamic text content
/// - [ImageBase64Content]: For base64-encoded images
/// - [ImageFileContent]: For local file images
/// - [ImageAssetContent]: For Flutter asset images
/// - [ImageURLContent]: For remote images
///
/// Example usage:
/// ```dart
/// Map<String, VAPContent> contents = {
///   'username': TextContent('John Doe'),
///   'avatar': ImageURLContent('https://example.com/avatar.jpg'),
///   'logo': ImageAssetContent('assets/images/logo.png'),
/// };
/// ```
abstract class VAPContent {
  /// The type of content (e.g., 'text', 'image_url', 'image_file').
  String get contentType;

  /// The actual content value (text string, file path, URL, etc.).
  String get contentValue;

  /// Converts this content to a map for native platform communication.
  ///
  /// Returns a map containing the content type and value that can be
  /// serialized and sent to native platforms.
  Map<String, dynamic> get toMap {
    return {'contentType': contentType, 'contentValue': contentValue};
  }

  /// Creates a VAPContent instance from a map received from native platforms.
  ///
  /// This factory method automatically determines the appropriate subclass
  /// based on the content type and value in the map.
  ///
  /// Parameters:
  /// - [value]: Map containing 'contentType' and 'contentValue' keys
  ///
  /// Returns the appropriate VAPContent subclass instance.
  /// Throws [ArgumentError] if the content type is unknown.
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

/// Content type for dynamic text injection into VAP animations.
///
/// TextContent allows you to inject dynamic text into VAP animations at runtime.
/// The text will be rendered using the styling defined in the VAP file.
///
/// Example usage:
/// ```dart
/// TextContent username = TextContent('John Doe');
/// await controller.setVapTagContent('username', username);
/// ```
class TextContent extends VAPContent {
  /// The text content to display in the animation.
  final String text;

  /// Creates a TextContent with the specified text.
  ///
  /// Parameters:
  /// - [text]: The text string to inject into the animation
  TextContent(this.text);

  @override
  String get contentType => 'text';

  @override
  String get contentValue => text;
}

/// Content type for base64-encoded image injection into VAP animations.
///
/// ImageBase64Content allows you to inject images that are encoded as base64
/// strings directly into VAP animations. This is useful when you have image
/// data in memory or received from an API.
///
/// Example usage:
/// ```dart
/// String base64Data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
/// ImageBase64Content image = ImageBase64Content(base64Data);
/// await controller.setVapTagContent('avatar', image);
/// ```
class ImageBase64Content extends VAPContent {
  /// The base64-encoded image data.
  final String base64;

  /// Creates an ImageBase64Content with the specified base64 data.
  ///
  /// Parameters:
  /// - [base64]: Base64-encoded image string
  ImageBase64Content(this.base64);

  @override
  String get contentType => 'image_base64';

  @override
  String get contentValue => base64;
}

/// Content type for local file image injection into VAP animations.
///
/// ImageFileContent allows you to inject images from the device's file system
/// into VAP animations. The file path should point to a valid image file
/// accessible to the app.
///
/// Example usage:
/// ```dart
/// ImageFileContent image = ImageFileContent('/storage/emulated/0/Download/avatar.jpg');
/// await controller.setVapTagContent('avatar', image);
/// ```
class ImageFileContent extends VAPContent {
  /// The file system path to the image file.
  final String filePath;

  /// Creates an ImageFileContent with the specified file path.
  ///
  /// Parameters:
  /// - [filePath]: Absolute path to the image file on the device
  ImageFileContent(this.filePath);

  @override
  String get contentType => 'image_file';

  @override
  String get contentValue => filePath;
}

/// Content type for Flutter asset image injection into VAP animations.
///
/// ImageAssetContent allows you to inject images from your app's assets
/// into VAP animations. The asset must be declared in your pubspec.yaml file.
///
/// Example usage:
/// ```dart
/// ImageAssetContent logo = ImageAssetContent('assets/images/logo.png');
/// await controller.setVapTagContent('logo', logo);
/// ```
class ImageAssetContent extends VAPContent {
  /// The asset path as declared in pubspec.yaml.
  final String assetPath;

  /// Creates an ImageAssetContent with the specified asset path.
  ///
  /// Parameters:
  /// - [assetPath]: Path to the asset image (e.g., 'assets/images/logo.png')
  ImageAssetContent(this.assetPath);

  @override
  String get contentType => 'image_asset';

  @override
  String get contentValue => assetPath;
}

/// Content type for remote URL image injection into VAP animations.
///
/// ImageURLContent allows you to inject images from remote URLs into VAP
/// animations. The image will be downloaded and cached automatically.
///
/// Example usage:
/// ```dart
/// ImageURLContent avatar = ImageURLContent('https://example.com/avatar.jpg');
/// await controller.setVapTagContent('avatar', avatar);
/// ```
class ImageURLContent extends VAPContent {
  /// The URL of the remote image.
  final String url;

  /// Creates an ImageURLContent with the specified URL.
  ///
  /// Parameters:
  /// - [url]: HTTP/HTTPS URL pointing to an image file
  ImageURLContent(this.url);

  @override
  String get contentType => 'image_url';

  @override
  String get contentValue => url;
}
