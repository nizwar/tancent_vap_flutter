import Flutter
import UIKit
import QGVAPlayer
import Darwin.Mach

public class VapFlutterView: NSObject, FlutterPlatformView {
    private let _view: UIView
    private let channel: FlutterMethodChannel
    private var vapView: QGVAPWrapView?
    private var repeatCount: Int = 0
    private var playResult: FlutterResult?
    private var vapTagContents: [String: [String: Any]] = [:]
    
    init(
        context: CGRect,
        params: [String: Any]?,
        messenger: FlutterBinaryMessenger,
        id: Int64
    ) {
        _view = UIView(frame: context)
        channel = FlutterMethodChannel(name: "vap_view_\(id)", binaryMessenger: messenger)
        
        super.init()
        
        // Initialize VAP view with proper configuration
        vapView = QGVAPWrapView(frame: context)
        
        vapView?.center = _view.center
        // Set scaleType from params (matching Kotlin logic)
        if let scaleType = params?["scaleType"] as? String {
            switch scaleType {
            case "fitCenter":
                vapView?.contentMode = .aspectFit
                break
            case "centerCrop":
                vapView?.contentMode = .aspectFill
                break
            case "fitXY":
                 vapView?.contentMode = .scaleToFill
                break
            default:
                 vapView?.contentMode = .aspectFit
                break
            }
        } else {
            // Default scale type (matching Kotlin's default)
             vapView?.contentMode = .aspectFit
        }
        
        // Configure background color to prevent visual glitches
        vapView?.backgroundColor = UIColor.clear
        
        _view.backgroundColor = UIColor.clear
        
        channel.setMethodCallHandler(onMethodCall)
        
        // Add vapView to container
        if let vapView = vapView {
            vapView.translatesAutoresizingMaskIntoConstraints = false
            _view.addSubview(vapView)
            
            // Set up auto layout constraints
            NSLayoutConstraint.activate([
                vapView.topAnchor.constraint(equalTo: _view.topAnchor),
                vapView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
                vapView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
                vapView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
            ])
        }
        
        // Initial playback if filePath or assetName is provided (matching Kotlin)
        if let filePath = params?["filePath"] as? String {
            playFile(filePath)
        }
        if let assetName = params?["assetName"] as? String {
            playAsset(assetName)
        }
        if let loop = params?["loop"] as? Int {
            setLoop(loop)
        }
        if let mute = params?["mute"] as? Bool {
            setMute(mute)
        }
        
        // Store tag contents as Maps
        if let tagContents = params?["vapTagContents"] as? [String: [String: Any]] {
            for (tag, content) in tagContents {
                vapTagContents[tag] = content
                NSLog("Stored tag content for tag: \(tag), contentType: \(content["contentType"] ?? "unknown")")
            }
        } 
    }
    
    public func view() -> UIView {
        return _view
    }
    
    private func reset() {
        // Ensure cleanup happens on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            clearVapTagContents()
            
            // Stop VAP playback and clean up resources
            self.vapView?.stopHWDMP4()
            
            // Give a moment for VideoToolbox to clean up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Remove all subviews
                self._view.subviews.forEach { $0.removeFromSuperview() }
                
                // Clear the VAP view reference
                self.vapView = nil
                
                // Force garbage collection hint
                if #available(iOS 13.0, *) {
                    // Modern iOS versions handle this automatically
                } else {
                    // For older iOS versions, hint at memory cleanup
                    DispatchQueue.global(qos: .background).async {
                        // Trigger background cleanup
                    }
                }
            }
        }
    }
    
    private func dispose() {
        reset()
        channel.setMethodCallHandler(nil)
    }
     
    private func onMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "dispose":
            dispose()
            result(nil)
            
        case "playFile":
            if let args = call.arguments as? [String: Any],
               let filePath = args["filePath"] as? String {
                playFile(filePath, result)
            }
            
        case "playAsset":
            if let args = call.arguments as? [String: Any],
               let assetName = args["assetName"] as? String {
                playAsset(assetName, result)
            }
            
        case "stop":
            stop()
            result(nil)
            
        case "setLoop":
            if let args = call.arguments as? [String: Any],
               let loop = args["loop"] as? Int {
                setLoop(loop)
            } else {
                setLoop(0)
            }
            result(nil)
            
        case "setMute":
            if let args = call.arguments as? [String: Any],
               let mute = args["mute"] as? Bool {
                setMute(mute)
            } else {
                setMute(false)
            }
            result(nil)
            
        case "setScaleType":
            if let args = call.arguments as? [String: Any],
               let scaleType = args["scaleType"] as? String {
                setScaleType(scaleType)
            }
            result(nil)
            
        case "setVapTagContent":
            if let args = call.arguments as? [String: Any],
               let tag = args["tag"] as? String,
               let contentMap = args["content"] as? [String: Any] {
                setVapTagContent(tag: tag, contentMap: contentMap)
            }
            result(nil)
            
        case "setVapTagContents":
            if let args = call.arguments as? [String: Any],
               let contents = args["contents"] as? [String: [String: Any]] {
                setVapTagContents(contents)
            }
            result(nil)
            
        case "getVapTagContent":
            if let args = call.arguments as? [String: Any],
               let tag = args["tag"] as? String {
                result(getVapTagContent(tag: tag))
            } else {
                result(nil)
            }
            
        case "getAllVapTagContents":
            result(vapTagContents)
            
        case "clearVapTagContents":
            clearVapTagContents()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
     
    private func playFile(_ filePath: String, _ result: FlutterResult? = nil) {
        // Ensure we're on the main thread for UI operations
        self.playResult = result
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let vapView = self.vapView else { return }
 
            // Stop any existing playback first
            vapView.stopHWDMP4()
            
            // Configure VAP player with better error handling
            do {
                guard FileManager.default.fileExists(atPath: filePath) else {
                    self.sendFailedEvent(errorCode: -1, errorType: "FILE_NOT_FOUND", errorMsg: "VAP file not found: \(filePath)")
                    return
                }
                
                // Check file size (VAP files shouldn't be too large for memory)
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
                if let fileSize = fileAttributes[.size] as? NSNumber {
                    let fileSizeInMB = fileSize.doubleValue / (1024 * 1024)
                    // Reject extremely large files that will definitely cause issues
                    if fileSizeInMB > 100 {
                        self.sendFailedEvent(errorCode: -1006, errorType: "FILE_TOO_LARGE",  errorMsg: "VAP file too large (\(fileSizeInMB) MB), maximum size is 100MB")
                        playError(-1006, "FILE_TOO_LARGE", "VAP file too large (\(fileSizeInMB) MB), maximum size is 100MB")
                        return
                    }
                }
                // Start playback with delegate
                vapView.playHWDMP4(filePath, repeatCount: self.repeatCount, delegate: self)
            
                
            } catch {
                self.sendFailedEvent(errorCode: -2, errorType: "FILE_PLAYBACK_ERROR", errorMsg: "Failed to play VAP file: \(error.localizedDescription)")
            }
        }
    }
    
    private func playAsset(_ assetName: String, _ result: FlutterResult? = nil) { 
        let key = FlutterDartProject.lookupKey(forAsset: assetName)
        if let bundlePath = Bundle.main.path(forResource: key, ofType: nil) {
            playFile(bundlePath)
        } else {
            sendFailedEvent(errorCode: -1, errorType: "FILE_NOT_FOUND", errorMsg: "Asset not found: \(assetName)")
        }
    }
    
    private func stop() {
        vapView?.stopHWDMP4()
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onVideoDestroy", arguments: nil)
        }
    }
    
    private func setLoop(_ loop: Int) {
        repeatCount = loop
    }
    
    private func setMute(_ mute: Bool) {
        vapView?.setMute(mute)
    }
    
    private func setScaleType(_ scaleType: String) {
        switch scaleType {
        case "fitCenter":
            vapView?.contentMode = .aspectFit
            break
        case "centerCrop":
            vapView?.contentMode = .aspectFill
            break
        case "fitXY":
            vapView?.contentMode = .scaleToFill
            break
        default:
            vapView?.contentMode = .aspectFit
            break
        }
    }
    
    // MARK: - VAP Tag Content Management
    private func setVapTagContent(tag: String, contentMap: [String: Any]) {
        vapTagContents[tag] = contentMap
    }
    
    private func setVapTagContents(_ contents: [String: [String: Any]]) {
        vapTagContents.merge(contents) { (_, new) in new }
    }
    
    private func getVapTagContent(tag: String) -> String? {
        guard let contentMap = vapTagContents[tag],
              let contentValue = contentMap["contentValue"] as? String else {
            return nil
        }
        return contentValue
    }
    
    private func clearVapTagContents() {
        vapTagContents.removeAll()
    }
    
    // MARK: - Event Handling
    private func sendFailedEvent(errorCode: Int, errorType: String, errorMsg: String?) {
        let args: [String: Any?] = [
            "errorCode": errorCode,
            "errorType": errorType,
            "errorMsg": errorMsg
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onFailed", arguments: args)
        }
    }
    
    private func sendVideoCompleteEvent() {
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onVideoComplete", arguments: nil)
        }
    }
    
    private func sendVideoRenderEvent(frameIndex: Int, config: [String: Any]?) {
        let args: [String: Any?] = [
            "frameIndex": frameIndex,
            "config": config
        ]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onVideoRender", arguments: args)
        }
    }
    
    private func sendVideoConfigReadyEvent(config: [String: Any]) {
        let args = ["config": config]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onVideoConfigReady", arguments: args)
        }
    }
}

// MARK: - HWDMP4PlayDelegate
extension VapFlutterView: VAPWrapViewDelegate {
    
    func shouldStartPlayMP4(_ container: QGVAPWrapView, config: QGVAPConfigModel) -> Bool {
        var animConfigMap: [String: Any] = [:]
        animConfigMap["width"] = config.info.size.width
        animConfigMap["height"] = config.info.size.height
        animConfigMap["fps"] = config.info.fps
        animConfigMap["totalFrames"] = config.info.framesCount
        animConfigMap["videoHeight"] = config.info.videoSize.height
        animConfigMap["videoWidth"] = config.info.videoSize.width
        animConfigMap["isMix"] = config.info.isMerged
        animConfigMap["orien"] = config.info.targetOrientaion.rawValue
        animConfigMap["alphaPointRect"] = [
            "x": config.info.alphaAreaRect.minX,
            "y": config.info.alphaAreaRect.minY,
            "w": config.info.alphaAreaRect.maxX,
            "h": config.info.alphaAreaRect.maxY
        ]
        animConfigMap["rgbPointRect"] = [
            "x": config.info.rgbAreaRect.minX,
            "y": config.info.rgbAreaRect.minY,
            "w": config.info.rgbAreaRect.maxX,
            "h": config.info.rgbAreaRect.maxY
        ]
        animConfigMap["version"] = config.info.version
        sendVideoConfigReadyEvent(config: animConfigMap)
        return true
    }
    
    func viewDidStartPlayMP4(_ container: QGVAPWrapView) {
        
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onVideoStart", arguments: nil)
        }
    }
    
    func viewDidPlayMP4AtFrame(_ frame: QGMP4AnimatedImageFrame, view container: QGVAPWrapView) {
        let args: [String: Any] = ["frameIndex": frame.index]
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onVideoRender", arguments: args)
        }
    }
    
    func viewDidStopPlayMP4(_ lastFrameIndex: Int, view container: QGVAPWrapView) {
        playSuccess()
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onVideoDestroy", arguments: nil)
        }
    }
    
    func viewDidFinishPlayMP4(_ totalFrameCount: Int, view container: QGVAPWrapView) {
        playSuccess()
        sendVideoCompleteEvent()
    }
    
    func viewDidFailPlayMP4(_ error: NSError) {
        // Handle specific VideoToolbox errors
        var errorMsg = error.localizedDescription
        var errorCode = error.code
        
        // Check for common VideoToolbox errors
        if error.domain == "com.apple.videotoolbox" || error.domain.contains("VT") {
            switch error.code {
            case -12909: // kVTVideoDecoderBadDataErr
                errorMsg = "Invalid or corrupted video data. Please check your VAP file encoding."
                errorCode = -1001
            case -12911: // kVTVideoDecoderMalfunctionErr
                errorMsg = "Video decoder malfunction. Try restarting the app."
                errorCode = -1002
            case -12912: // kVTVideoDecoderNotAvailableNowErr
                errorMsg = "Video decoder not available. Device may be under memory pressure."
                errorCode = -1003
            case -12913: // kVTInvalidSessionErr
                errorMsg = "Invalid video session. Please try playing the file again."
                errorCode = -1004
            default:
                errorMsg = "VideoToolbox error: \(error.localizedDescription)"
                errorCode = -1000
            }
        }
        playError(errorCode, "VIDEO_PLAYBACK_ERROR", errorMsg)
        sendFailedEvent(errorCode: errorCode, errorType:"VIDEO_PLAYBACK_ERROR", errorMsg: errorMsg)
    }
    
    func playError(_ code:Int, _ errorType:String, _ errorMsg:String){
        if(playResult != nil){
            playResult?(FlutterError(code: String(code),message: errorMsg,details: ["errorType": errorType]))
            playResult = nil
        }
    }
    
    func playSuccess(){
        if(playResult != nil){
            playResult?(nil)
            playResult = nil
        }
    }
    //       MARK: - Resource Management Delegate Methods
    public func vapWrapview_content(forVapTag tag: String, resource info: QGVAPSourceInfo) -> String {
        guard let contentMap = vapTagContents[tag],
              let contentValue = contentMap["contentValue"] as? String else {
            return tag
        }
        
        // If the resource type is text, return the content value
        if info.type == .text || info.type == .textStr {
            return contentValue
        }
        
        // For other resource types (images, etc.), return the tag
        return tag
    }
    
    public func vapWrapView_loadVapImage(withURL urlStr: String, context: [AnyHashable : Any], completion completionBlock: @escaping VAPImageCompletionBlock) {
        print("URLNYA : " + urlStr + " INI VAPIMAGECONTENT : " + String(describing: vapTagContents) + "\n")
        // First check if we have content for this tag in vapTagContents
        if let contentMap = vapTagContents[urlStr],
           let contentValue = contentMap["contentValue"] as? String,
           let contentType = contentMap["contentType"] as? String {
            handleVapTagContent(content: contentValue, contentType: contentType, tag: urlStr, completion: completionBlock)
            return
        }
        
        // Fallback to original URL loading if no tag content is found
        guard let url = URL(string: urlStr) else {
            completionBlock(nil, NSError(domain: "VAPImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL and no tag content found"]), urlStr)
            return
        }
        
        // Simple URLSession implementation - replace with your preferred image loading library
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completionBlock(nil, error as NSError, urlStr)
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    completionBlock(nil, NSError(domain: "VAPImageLoader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]), urlStr)
                    return
                }
                
                completionBlock(image, nil, urlStr)
            }
        }.resume()
    }
    
    func loadVapImageWithURL(_ urlStr: String, context: [String: Any], completion: @escaping VAPImageCompletionBlock) {
        // First check if we have content for this tag in vapTagContents
        if let contentMap = vapTagContents[urlStr],
           let contentValue = contentMap["contentValue"] as? String,
           let contentType = contentMap["contentType"] as? String {
            handleVapTagContent(content: contentValue, contentType: contentType, tag: urlStr, completion: completion)
            return
        }
        
        // Fallback to original URL loading if no tag content is found
        guard let url = URL(string: urlStr) else {
            completion(nil, NSError(domain: "VAPImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL and no tag content found"]), urlStr)
            return
        }
        
        // Simple URLSession implementation - replace with your preferred image loading library
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error as NSError, urlStr)
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    completion(nil, NSError(domain: "VAPImageLoader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]), urlStr)
                    return
                }
                
                completion(image, nil, urlStr)
            }
        }.resume()
    }
    
    private func handleVapTagContent(content: String, contentType: String, tag: String, completion: @escaping VAPImageCompletionBlock) {
        NSLog("Processing tag: \(tag), contentType: \(contentType)")
        
        switch contentType {
        case "text":
            handleTextContent(content: content, tag: tag, completion: completion)
        case "image_base64":
            handleImageBase64Content(content: content, tag: tag, completion: completion)
        case "image_file":
            handleImageFileContent(content: content, tag: tag, completion: completion)
        case "image_asset":
            handleImageAssetContent(content: content, tag: tag, completion: completion)
        case "image_url":
            handleImageUrlContent(content: content, tag: tag, completion: completion)
        default:
            NSLog("Unsupported content type: \(contentType) for tag: \(tag)")
            completion(nil, NSError(domain: "VAPImageLoader", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unsupported content type: \(contentType)"]), tag)
        }
    }
    
    // MARK: - Content Type Handlers
    
    private func handleTextContent(content: String, tag: String, completion: @escaping VAPImageCompletionBlock) {
        // Text content is not handled by image loading, skip
        NSLog("Text content type for tag: \(tag), skipping image loading")
        completion(nil, nil, tag)
    }
    
    private func handleImageBase64Content(content: String, tag: String, completion: @escaping VAPImageCompletionBlock) {
        DispatchQueue.global(qos: .userInitiated).async {
            var base64String = content
            
            // Remove data URL prefix if present (e.g., "data:image/png;base64,")
            if content.hasPrefix("data:image/") {
                if let commaRange = content.range(of: ",") {
                    base64String = String(content[commaRange.upperBound...])
                }
            } else if content.hasPrefix("base64:") {
                base64String = String(content.dropFirst(7)) // Remove "base64:" prefix
            }
            
            guard let imageData = Data(base64Encoded: base64String),
                  let image = UIImage(data: imageData) else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "VAPImageLoader", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode base64 image for tag: \(tag)"]), tag)
                }
                return
            }
            
            DispatchQueue.main.async {
                NSLog("Successfully decoded base64 image for tag: \(tag)")
                completion(image, nil, tag)
            }
        }
    }
    
    private func handleImageFileContent(content: String, tag: String, completion: @escaping VAPImageCompletionBlock) {
        DispatchQueue.global(qos: .userInitiated).async {
            var fullPath = content
            
            // Handle different file path types
            if content.hasPrefix("/") {
                // Absolute path
                fullPath = content
            } else if content.hasPrefix("file://") {
                // File URL
                fullPath = String(content.dropFirst(7))
            } else {
                // Relative path - check in Documents directory
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let documentFilePath = documentsPath + "/" + content
                
                if FileManager.default.fileExists(atPath: documentFilePath) {
                    fullPath = documentFilePath
                } else {
                    // Use as-is and let it fail if invalid
                    fullPath = content
                }
            }
            
            guard FileManager.default.fileExists(atPath: fullPath) else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "VAPImageLoader", code: -4, userInfo: [NSLocalizedDescriptionKey: "File not found: \(fullPath) for tag: \(tag)"]), tag)
                }
                return
            }
            
            guard let image = UIImage(contentsOfFile: fullPath) else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "VAPImageLoader", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from file: \(fullPath) for tag: \(tag)"]), tag)
                }
                return
            }
            
            DispatchQueue.main.async {
                NSLog("Successfully loaded file image for tag: \(tag) from: \(fullPath)")
                completion(image, nil, tag)
            }
        }
    }
    
    private func handleImageAssetContent(content: String, tag: String, completion: @escaping VAPImageCompletionBlock) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Try as Flutter asset first
            let assetKey = FlutterDartProject.lookupKey(forAsset: content)
            var fullPath: String?
            
            if let assetPath = Bundle.main.path(forResource: assetKey, ofType: nil) {
                fullPath = assetPath
            } else if let bundlePath = Bundle.main.path(forResource: content, ofType: nil) {
                // Try as direct bundle resource
                fullPath = bundlePath
            }
            
            guard let validPath = fullPath, FileManager.default.fileExists(atPath: validPath) else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "VAPImageLoader", code: -4, userInfo: [NSLocalizedDescriptionKey: "Asset not found: \(content) for tag: \(tag)"]), tag)
                }
                return
            }
            
            guard let image = UIImage(contentsOfFile: validPath) else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "VAPImageLoader", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to load asset image: \(content) for tag: \(tag)"]), tag)
                }
                return
            }
            
            DispatchQueue.main.async {
                NSLog("Successfully loaded asset image for tag: \(tag) from: \(validPath)")
                completion(image, nil, tag)
            }
        }
    }
    
    private func handleImageUrlContent(content: String, tag: String, completion: @escaping VAPImageCompletionBlock) {
        guard let url = URL(string: content) else {
            completion(nil, NSError(domain: "VAPImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(content) for tag: \(tag)"]), tag)
            return
        }
        
        NSLog("Loading image from URL: \(content) for tag: \(tag)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("Failed to load image from URL: \(content) for tag: \(tag), error: \(error.localizedDescription)")
                    completion(nil, error as NSError, tag)
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    completion(nil, NSError(domain: "VAPImageLoader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from URL data: \(content) for tag: \(tag)"]), tag)
                    return
                }
                
                NSLog("Successfully loaded image from URL: \(content) for tag: \(tag)")
                completion(image, nil, tag)
            }
        }.resume()
    }
}
