import Flutter
import flutter_sharing_intent
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "dev.ultrasend/file_times",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "applyReceived" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String,
              let modifiedMs = args["modifiedMs"] as? Int,
              let createdMs = args["createdMs"] as? Int else {
          result(FlutterError(code: "INVALID_ARG", message: "missing args", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.creationDate = Date(timeIntervalSince1970: Double(createdMs) / 1000.0)
        values.contentModificationDate = Date(timeIntervalSince1970: Double(modifiedMs) / 1000.0)
        do {
          var mutableUrl = url
          try mutableUrl.setResourceValues(values)
          result(true)
        } catch {
          result(FlutterError(code: "SET_FAILED", message: error.localizedDescription, details: nil))
        }
      }

      // Set up the native tab bar channel and its coordinator controller
      // Only register on iOS 26+ where Liquid Glass is available.
      if #available(iOS 26.0, *) {
        let nativeTabBarChannel = FlutterMethodChannel(
          name: "dev.ultrasend/native_tab_bar",
          binaryMessenger: controller.binaryMessenger
        )
        let nativeTabBarController = NativeTabBarController(
          flutterViewController: controller,
          channel: nativeTabBarChannel
        )
        nativeTabBarChannel.setMethodCallHandler { call, result in
          if call.method == "updateState" {
            if let args = call.arguments as? [String: Any] {
              nativeTabBarController.updateState(arguments: args)
              result(true)
            } else {
              result(FlutterError(code: "INVALID_ARG", message: "arguments must be a dictionary", details: nil))
            }
          } else if call.method == "setVisible" {
            if let visible = call.arguments as? Bool {
              nativeTabBarController.setForceHidden(!visible)
              result(true)
            } else {
              result(FlutterError(code: "INVALID_ARG", message: "argument must be a boolean", details: nil))
            }
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
      }
    }
    return didFinish
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let sharingIntent = SwiftFlutterSharingIntentPlugin.instance
    if sharingIntent.hasSameSchemePrefix(url: url) {
      return sharingIntent.application(app, open: url, options: options)
    }
    return super.application(app, open: url, options: options)
  }
}

class PassThroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for subview in subviews {
            if !subview.isHidden && subview.isUserInteractionEnabled {
                let localPoint = convert(point, to: subview)
                if subview.point(inside: localPoint, with: event) {
                    return true
                }
            }
        }
        return false
    }
}

class NativeTabBarController: NSObject, NativeTabBarViewDelegate {
    private let flutterViewController: FlutterViewController
    private let channel: FlutterMethodChannel
    
    private var containerView: UIView?
    private var tabBarView: NativeTabBarView?
    private var bottomConstraint: NSLayoutConstraint?
    
    private var isBarVisible = false
    private var isDesiredVisible = false
    private var isForceHidden = false
    
    init(flutterViewController: FlutterViewController, channel: FlutterMethodChannel) {
        self.flutterViewController = flutterViewController
        self.channel = channel
        super.init()
        setupTabBar()
    }
    
    private func setupTabBar() {
        let container = PassThroughView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.layer.masksToBounds = false
        
        let bar = NativeTabBarView()
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(bar)
        flutterViewController.view.addSubview(container)
        
        self.containerView = container
        self.tabBarView = bar
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: flutterViewController.view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: flutterViewController.view.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: 140),
            
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        let constraint = container.bottomAnchor.constraint(equalTo: flutterViewController.view.bottomAnchor, constant: 0)
        constraint.isActive = true
        self.bottomConstraint = constraint
        
        container.alpha = 0
        container.transform = CGAffineTransform(translationX: 0, y: 150)
    }
    
    func updateState(arguments: [String: Any]) {
        guard let visible = arguments["visible"] as? Bool,
              let selectedIndex = arguments["selectedIndex"] as? Int,
              let badgeCount = arguments["badgeCount"] as? Int,
              let primaryColorHex = arguments["primaryColorHex"] as? String,
              let connectLabel = arguments["connectLabel"] as? String,
              let filesLabel = arguments["filesLabel"] as? String,
              let settingsLabel = arguments["settingsLabel"] as? String else {
            return
        }
        
        let isDarkMode = arguments["isDarkMode"] as? Bool ?? false
        if #available(iOS 13.0, *) {
            containerView?.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        }
        
        tabBarView?.update(
            selectedIndex: selectedIndex,
            badgeCount: badgeCount,
            primaryColorHex: primaryColorHex,
            connectLabel: connectLabel,
            filesLabel: filesLabel,
            settingsLabel: settingsLabel
        )
        
        self.isDesiredVisible = visible
        updateVisibility()
    }
    
    func setForceHidden(_ forceHidden: Bool) {
        guard self.isForceHidden != forceHidden else { return }
        self.isForceHidden = forceHidden
        updateVisibility()
    }
    
    private func updateVisibility() {
        let shouldBeVisible = isDesiredVisible && !isForceHidden
        guard isBarVisible != shouldBeVisible else { return }
        isBarVisible = shouldBeVisible
        
        flutterViewController.view.layoutIfNeeded()
        
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: { [weak self] in
                guard let self = self else { return }
                if shouldBeVisible {
                    self.containerView?.alpha = 1
                    self.containerView?.transform = .identity
                    self.bottomConstraint?.constant = 0
                } else {
                    self.containerView?.alpha = 0
                    self.containerView?.transform = CGAffineTransform(translationX: 0, y: 150)
                    self.bottomConstraint?.constant = 150
                }
                self.flutterViewController.view.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    // MARK: - NativeTabBarViewDelegate
    
    func tabBarView(_ tabBarView: NativeTabBarView, didSelectTabAt index: Int) {
        channel.invokeMethod("selectTab", arguments: index)
    }
    
    func tabBarViewDidTapOutbox(_ tabBarView: NativeTabBarView) {
        channel.invokeMethod("openPendingFiles", arguments: nil)
    }
}
