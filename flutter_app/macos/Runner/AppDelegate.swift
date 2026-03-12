//
//  StatusBarController.swift
//  Runner
//
//  Created by sky on 17/05/23.
//

import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var statusBarController: StatusBarController?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    let panelFlutterViewController = FlutterViewController()
    panelFlutterViewController.mouseTrackingMode = .inKeyWindow
    RegisterGeneratedPlugins(registry: panelFlutterViewController)

    let flutterPanel = StatusBarPanel(
      contentViewController: panelFlutterViewController,
      contentSize: NSSize(width: 360, height: 360)
    )
    statusBarController = StatusBarController(panel: flutterPanel)

    mainFlutterWindow?.orderOut(nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.statusBarController?.showOnLaunch()
    }
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
