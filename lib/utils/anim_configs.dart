import 'package:flutter/painting.dart';
import 'package:vap/utils/constant.dart';

class VAPConfigs {
  final int width;
  final int height;
  final int fps;
  final int totalFrames;
  final bool isMix;
  final VideoOrientation orien;
  final int videoHeight;
  final int videoWidth;
  final Rect alphaPointRect;
  final Rect rgbPointRect;
  final int version;

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
      alphaPointRect: Rect.fromLTRB(json['alphaPointRect']["x"], json['alphaPointRect']["y"], json['alphaPointRect']["w"], json['alphaPointRect']["h"]),
      rgbPointRect: Rect.fromLTRB(json['rgbPointRect']["x"], json['rgbPointRect']["y"], json['rgbPointRect']["w"], json['rgbPointRect']["h"]),
      version: json['version'] as int,
    );
  }

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
