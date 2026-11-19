import ActivityKit
import Flutter
import Foundation

/// Dart ↔ ActivityKit 桥接。
///
/// 数据通过 ContentState 直接传递，不依赖 App Groups。
@available(iOS 16.1, *)
final class LiveActivityBridge {
  static let shared = LiveActivityBridge()
  static let channelName = "com.sirandev.auroraweather/live_activity"

  private var channel: FlutterMethodChannel?

  private init() {}

  /// 在引擎初始化后注册 MethodChannel。
  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isSupported":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    case "start", "update":
      guard
        let args = call.arguments as? [String: Any],
        let state = Self.contentState(from: args)
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "invalid live activity payload",
            details: nil
          )
        )
        return
      }
      Task { @MainActor in
        await self.upsert(state: state, result: result)
      }
    case "end":
      Task { @MainActor in
        for activity in Activity<AuroraWeatherActivityAttributes>.activities {
          if #available(iOS 16.2, *) {
            await activity.end(nil, dismissalPolicy: .immediate)
          } else {
            await activity.end()
          }
        }
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 已有活动则更新，否则新建。
  @MainActor
  private func upsert(
    state: AuroraWeatherActivityAttributes.ContentState,
    result: @escaping FlutterResult
  ) async {
    if let existing = Activity<AuroraWeatherActivityAttributes>.activities.first {
      if #available(iOS 16.2, *) {
        let content = ActivityContent(
          state: state,
          staleDate: Date().addingTimeInterval(15 * 60)
        )
        await existing.update(content)
      } else {
        await existing.update(using: state)
      }
      result(nil)
      return
    }

    do {
      let attributes = AuroraWeatherActivityAttributes()
      if #available(iOS 16.2, *) {
        let content = ActivityContent(
          state: state,
          staleDate: Date().addingTimeInterval(15 * 60)
        )
        _ = try Activity.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
      } else {
        _ = try Activity.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
      }
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "start_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  static func contentState(
    from data: [String: Any]
  ) -> AuroraWeatherActivityAttributes.ContentState? {
    guard
      let city = data["city"] as? String,
      let temp = data["temp"] as? String,
      let text = data["text"] as? String
    else {
      return nil
    }

    let updatedAt: Date
    if let seconds = data["updatedAt"] as? NSNumber {
      updatedAt = Date(timeIntervalSince1970: seconds.doubleValue)
    } else {
      updatedAt = Date()
    }

    return AuroraWeatherActivityAttributes.ContentState(
      city: city,
      temp: temp,
      feelsLike: data["feelsLike"] as? String ?? "",
      text: text,
      icon: data["icon"] as? String ?? "",
      tempMax: data["tempMax"] as? String ?? "",
      tempMin: data["tempMin"] as? String ?? "",
      updatedAt: updatedAt
    )
  }
}
