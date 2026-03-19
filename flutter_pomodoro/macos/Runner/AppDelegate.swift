import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let statusBarMenuChannelName = "pomogotchi/status_bar_menu"
  private var statusBarMenuChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  private var statusBarController: StatusBarController?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let panelFlutterViewController = FlutterViewController()
    panelFlutterViewController.mouseTrackingMode = .inKeyWindow
    RegisterGeneratedPlugins(registry: panelFlutterViewController)
    statusBarMenuChannel = FlutterMethodChannel(
      name: statusBarMenuChannelName,
      binaryMessenger: panelFlutterViewController.engine.binaryMessenger
    )

    let flutterPanel = StatusBarPanel(
      contentViewController: panelFlutterViewController,
      contentSize: NSSize(width: 360, height: 360)
    )
    statusBarController = StatusBarController(
      panel: flutterPanel,
      channel: statusBarMenuChannel
    )

    mainFlutterWindow?.orderOut(nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.statusBarController?.showOnLaunch()
    }
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

final class StatusBarPanel: NSPanel {
  init(contentViewController: NSViewController, contentSize: NSSize) {
    super.init(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    self.contentViewController = contentViewController
    setContentSize(contentSize)
    isReleasedWhenClosed = false
    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
    hidesOnDeactivate = false
    hasShadow = true
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovable = true
    isMovableByWindowBackground = true
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true
  }

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }
}

final class StatusBarController: NSObject, NSWindowDelegate {
  private let statusItem: NSStatusItem
  private let panel: StatusBarPanel
  private let channel: FlutterMethodChannel?
  private let contextMenu = NSMenu()
  private var hasCustomPanelPosition = false

  init(panel: StatusBarPanel, channel: FlutterMethodChannel?) {
    self.panel = panel
    self.channel = channel
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    super.init()

    panel.delegate = self
    configureContextMenu()

    if let statusBarButton = statusItem.button {
      statusBarButton.image = NSImage(named: "MenuBarIcon")
      statusBarButton.imagePosition = .imageOnly
      statusBarButton.action = #selector(handleStatusItemClick(_:))
      statusBarButton.target = self
      statusBarButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
  }

  @objc private func handleStatusItemClick(_ sender: Any?) {
    switch NSApp.currentEvent?.type {
    case .rightMouseUp:
      showContextMenu()
    default:
      togglePanel(sender)
    }
  }

  func showOnLaunch() {
    showOnLaunch(remainingAttempts: 20)
  }

  private func showOnLaunch(remainingAttempts: Int) {
    guard statusBarButtonFrameOnScreen() != nil else {
      guard remainingAttempts > 0 else {
        showPanel(nil)
        return
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.showOnLaunch(remainingAttempts: remainingAttempts - 1)
      }
      return
    }

    showPanel(nil)
  }

  private func togglePanel(_ sender: Any?) {
    if panel.isVisible {
      hidePanel(sender)
    } else {
      showPanel(sender)
    }
  }

  private func showPanel(_ sender: Any?) {
    if !hasCustomPanelPosition {
      guard let statusBarFrame = statusBarButtonFrameOnScreen() else {
        return
      }

      var panelOrigin = NSPoint(
        x: statusBarFrame.midX - (panel.frame.width / 2),
        y: statusBarFrame.minY - panel.frame.height - 8
      )

      if let screen = screenContaining(rect: statusBarFrame) ?? NSScreen.main {
        let visibleFrame = screen.visibleFrame
        panelOrigin.x = min(
          max(panelOrigin.x, visibleFrame.minX + 8),
          visibleFrame.maxX - panel.frame.width - 8
        )
        panelOrigin.y = max(visibleFrame.minY + 8, panelOrigin.y)
      }

      panel.setFrameOrigin(panelOrigin)
    }

    NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
    panel.orderFrontRegardless()
    panel.makeKeyAndOrderFront(sender)
    panel.makeMain()
    panel.makeFirstResponder(panel.contentViewController?.view)
  }

  private func hidePanel(_ sender: Any?) {
    panel.orderOut(sender)
  }

  private func configureContextMenu() {
    contextMenu.autoenablesItems = false
    contextMenu.items = [
      NSMenuItem(title: "Reset Position", action: #selector(resetPanelPosition(_:)), keyEquivalent: ""),
      NSMenuItem(title: "Sign Out", action: #selector(signOut(_:)), keyEquivalent: ""),
      NSMenuItem.separator(),
      NSMenuItem(title: "Close App", action: #selector(quitApp(_:)), keyEquivalent: "q"),
    ]

    for item in contextMenu.items {
      item.target = self
    }
  }

  private func showContextMenu() {
    contextMenu.items.first?.isEnabled = hasCustomPanelPosition
    statusItem.menu = contextMenu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @objc private func resetPanelPosition(_ sender: Any?) {
    hasCustomPanelPosition = false
    showPanel(sender)
  }

  @objc private func signOut(_ sender: Any?) {
    hidePanel(sender)
    channel?.invokeMethod("signOut", arguments: nil)
  }

  @objc private func quitApp(_ sender: Any?) {
    NSApp.terminate(sender)
  }

  private func statusBarButtonFrameOnScreen() -> NSRect? {
    guard
      let statusBarButton = statusItem.button,
      let statusBarWindow = statusBarButton.window
    else {
      return nil
    }

    let buttonFrameInWindow = statusBarButton.convert(statusBarButton.bounds, to: nil)
    let statusBarFrame = statusBarWindow.convertToScreen(buttonFrameInWindow)

    guard statusBarFrame.width > 0, statusBarFrame.height > 0 else {
      return nil
    }

    guard let screen = screenContaining(rect: statusBarFrame) ?? statusBarWindow.screen ?? NSScreen.main else {
      return nil
    }

    let distanceFromTop = abs(screen.frame.maxY - statusBarFrame.maxY)
    guard distanceFromTop < 80 else {
      return nil
    }

    return statusBarFrame
  }

  private func screenContaining(rect: NSRect) -> NSScreen? {
    NSScreen.screens.first { $0.frame.intersects(rect) }
  }

  func windowDidMove(_ notification: Notification) {
    guard panel.isVisible else {
      return
    }

    hasCustomPanelPosition = true
  }
}
