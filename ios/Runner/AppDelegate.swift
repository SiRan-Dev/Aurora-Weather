import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 注册 iOS 实时活动（Live Activity / 灵动岛）桥接
    if #available(iOS 16.1, *) {
      if let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "AuroraLiveActivityBridge"
      ) {
        LiveActivityBridge.shared.register(messenger: registrar.messenger())
      }
    }
  }
}
