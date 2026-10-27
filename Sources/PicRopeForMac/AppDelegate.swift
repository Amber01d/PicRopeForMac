import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var lastCaptureDates: [Date] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                                           accessibilityDescription: "PicRope")
        statusItem.menu = buildMenu()

        // 启动监视器；常驻模式启动即显示
        ClipboardMonitorBridge.shared.start()
        RopePanel.shared.applySettings()
        if Settings.ropeAlwaysVisible {
            RopePanel.shared.show()
        }

        // 有新截图挂上时自动短暂展示绳子
        NotificationCenter.default.addObserver(forName: .picRopeItemAdded,
                                               object: nil, queue: .main) { _ in
            RopePanel.shared.cancelHide()
            RopePanel.shared.show()
            RopePanel.shared.scheduleHide()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(item("显示绳子", #selector(showRope)))
        menu.addItem(item("隐藏绳子", #selector(hideRope)))
        menu.addItem(.separator())
        menu.addItem(item("设置…", #selector(openSettings), ","))
        menu.addItem(item("清空绳子", #selector(clearAll)))
        menu.addItem(.separator())
        menu.addItem(item("退出 PicRope", #selector(quit), "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func showRope() {
        RopePanel.shared.cancelHide()
        RopePanel.shared.show()
    }

    @objc private func hideRope() {
        RopePanel.shared.hide()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func clearAll() {
        CaptureStore.shared.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let picRopeItemAdded = Notification.Name("picRopeItemAdded")
}
