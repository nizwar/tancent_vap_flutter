import Flutter
import UIKit

/** VapPlugin */
public class VapPlugin: NSObject, FlutterPlugin {
  
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VapPlugin()
        instance.onAttachedToEngine(registrar: registrar)
    }

    private func onAttachedToEngine(registrar: FlutterPluginRegistrar) {
        // Register the platform view factory for VapView
        let factory = VapViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "vap_view")
    }

}
