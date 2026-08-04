import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

    /// Badge-clear bridge — see NotificationService.clearIconBadge.
    /// (v385: the share-intake channel this used to piggyback on was
    /// removed with the ImHimShare extension; badge now has its own
    /// channel, and the name finally matches the Dart side.)
    static let badgeChannelName = "com.imhim.app/badge"

    private var badgeChannel: FlutterMethodChannel?
    // Kept alive for the app's lifetime — owns the MediaPipe landmarker.
    private var mediaPipePlugin: MediaPipeFaceLandmarkerPlugin?
    private var mediaPipeChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            badgeChannel = FlutterMethodChannel(
                name: AppDelegate.badgeChannelName,
                binaryMessenger: controller.binaryMessenger
            )
            badgeChannel?.setMethodCallHandler { [weak self] call, result in
                self?.handleMethodCall(call, result: result)
            }

            // MediaPipe FaceLandmarker (iris) — the Aura tab's real
            // eye-contact scoring. Held on the AppDelegate so the native
            // landmarker survives across detect calls.
            let mp = MediaPipeFaceLandmarkerPlugin()
            mediaPipePlugin = mp
            mediaPipeChannel = FlutterMethodChannel(
                name: MediaPipeFaceLandmarkerPlugin.channelName,
                binaryMessenger: controller.binaryMessenger
            )
            mediaPipeChannel?.setMethodCallHandler { call, result in
                mp.handle(call, result: result)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "clearAppBadge":
            // v298 — wipe the iOS app-icon red badge. The
            // flutter_local_notifications 17.x plugin doesn't expose
            // a badge setter, so cancelling delivered notifications
            // (which the Dart side already does) left the icon
            // showing "1" forever. This sets it back to 0 directly
            // via UNUserNotificationCenter (iOS 16+) with a fallback
            // to the deprecated applicationIconBadgeNumber API for
            // older devices.
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            } else {
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
