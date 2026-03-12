import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    
    var statusBar: NSStatusItem?
    var popover = NSPopover()
    var flutterViewController: FlutterViewController?
    
    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        statusBar = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = statusBar?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.action = #selector(togglePopover(_:))
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject) {
        print("clicked!")
        
        if let button = statusBar?.button {
                if popover.isShown {
                    popover.performClose(sender)
                } else {
                    print("Open Popover")
                }
            }
    }
}
