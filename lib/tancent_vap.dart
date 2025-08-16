/// Tencent VAP Flutter Plugin
///
/// A Flutter plugin for playing VAP (Video Animation Player) animations from Tencent.
/// VAP is a high-performance video animation format that supports transparent backgrounds
/// and dynamic content injection.
///
/// This library provides:
/// - [VapView] widget for displaying VAP animations
/// - [VapController] for programmatic control of animations
/// - [VAPContent] classes for dynamic content injection
/// - [VAPConfigs] for animation configuration data
///
/// Example usage:
/// ```dart
/// VapView(
///   scaleType: ScaleType.fitCenter,
///   repeat: -1,
///   onViewCreated: (controller) {
///     controller.playAsset('animations/sample.mp4');
///   },
/// )
/// ```
library;

export 'widgets/vap_view.dart';
export 'utils/anim_configs.dart';
export 'utils/constant.dart';
