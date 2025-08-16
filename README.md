# Tencent VAP Flutter

A Flutter plugin that integrates Tencent's Video Animation Player (VAP) technology for high-performance video animations with dynamic content replacement. Supports multiple simultaneous animations through individual VAPView widgets.

## Features

- **High-Performance Playback**: Hardware-accelerated video animation rendering
- **Flexible Controls**: Loop options, scale types, audio control, lifecycle management  
- **Dynamic Content**: Text and image injection (Base64, files, assets, URLs)
- **Event System**: Complete lifecycle and error handling callbacks
- **Multiple Instances**: Run concurrent animations with independent widgets
 
### Platform Setup

**Android** (`android/app/build.gradle`):
```gradle
android {
        compileSdkVersion 34
        defaultConfig {
                minSdkVersion 21
        }
}
```

**iOS** (`ios/Podfile`):
```ruby
platform :ios, '11.0'
```

## Quick Start

```dart
// Basic VAP animation
VapView(
    scaleType: ScaleType.fitCenter,
    repeat: -1,
    onViewCreated: (controller) {
        controller.setAnimListener(
            onVideoStart: () => print('Started'),
            onVideoComplete: () => print('Completed'),
            onFailed: (code, type, msg) => print('Error: $code'),
        );
        controller.playAsset('animations/sample.mp4');
    },
)

// With dynamic content
VapView(
    vapTagContents: {
        'username': TextContent('John Doe'),
        'avatar': ImageURLContent('https://example.com/avatar.jpg'),
        'badge': ImageAssetContent('assets/images/badge.png'),
    },
    onViewCreated: (controller) => controller.playAsset('animations/profile.mp4'),
)
```
## API Reference

### VapView Properties
- `scaleType`: How video scales (`fitCenter`, `centerCrop`, `fitXY`)
- `repeat`: Loop count (0=once, -1=infinite, 1=2times, 2=3times and so on)
- `mute`: Audio enabled/disabled
- `vapTagContents`: Initial dynamic content
- `onViewCreated`: Controller callback

### VapController Methods
```dart
// Playback
await controller.playFile('/path/to/file.mp4');
await controller.playAsset('assets/anim.mp4');
await controller.stop();
await controller.setLoop(-1);

// Content Management
await controller.setVapTagContent('tag', TextContent('text'));
await controller.setVapTagContents({'tag1': content1, 'tag2': content2});
VAPContent? content = await controller.getVapTagContent('tag');
await controller.clearVapTagContents();

// Events
controller.setAnimListener(
    onVideoStart: () {},
    onVideoComplete: () {},
    onFailed: (code, type, msg) {},
);
```

### VAPContent Types
- `TextContent('text')` - Dynamic text
- `ImageBase64Content('base64...')` - Base64 images  
- `ImageFileContent('/path/file.jpg')` - Local files
- `ImageAssetContent('assets/img.png')` - Flutter assets
- `ImageURLContent('https://url.jpg')` - Remote images

## Error Handling

Common error codes:
- `-1`: File not found
- `-2`: Playback error  
- `-1001`: Invalid video data
- `-1002`: Decoder malfunction
- `-1006`: File too large

```dart
controller.setAnimListener(
    onFailed: (code, type, message) {
        switch (code) {
            case -1: /* Handle file not found */; break;
            case -1001: /* Handle corrupted data */; break;
            default: print('Error $code: $message');
        }
    },
);
```

## Best Practices

- **Memory Management**: Always dispose controllers in `dispose()`
- **Batch Updates**: Use `setVapTagContents()` for multiple content updates
- **Error Handling**: Wrap playback calls in try-catch blocks
- **Performance**: Use appropriate scale types and avoid unnecessary infinite loops

## Troubleshooting

1. **Animation not playing**: Check VAP file exists, verify asset registration
2. **Memory issues**: Dispose controllers, limit concurrent animations  
3. **Content not updating**: Verify tag names, set content before playback
4. **iOS build issues**: Ensure iOS 11.0+, run `pod install`

## Contributing

We welcome contributions to improve this plugin! Please feel free to:

- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation

## Credits

This Flutter plugin is built upon the excellent work of Tencent's VAP project:

- **Original VAP Project**: [https://github.com/Tencent/vap](https://github.com/Tencent/vap)
- **License**: MIT License
- **Tencent VAP Team**: For creating the foundational VAP technology

We extend our gratitude to the Tencent team for developing and open-sourcing the VAP framework, which makes high-performance video animations accessible to developers worldwide.

## [Instruction to create the Animation Video](https://github.com/Tencent/vap/blob/master/tool/README_en.md)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

The original Tencent VAP project is also licensed under the MIT License.
 