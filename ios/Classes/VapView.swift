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
    }
    
    public func view() -> UIView {
        return _view
    }
    
    private func reset() {
        // Ensure cleanup happens on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
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
    
    // MARK: - Resource Management Delegate Methods
    
    func contentForVapTag(_ tag: String) -> String? {
        return nil
    }
     
}
