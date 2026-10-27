import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏图标（菜单动态构建，打开时刷新屏幕列表）
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                                           accessibilityDescription: "PicRopeFM")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

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

        // 启动 3 秒后静默检查更新（可在设置中关闭）
        if Settings.autoCheckUpdate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                Updater.checkQuietly()
            }
        }
    }

    // MARK: - 菜单（动态构建，每次打开时刷新屏幕列表）

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item("显示绳子", #selector(showRope)))
        menu.addItem(item("隐藏绳子", #selector(hideRope)))
        // 绳子控制分组：重置位置 / 移动到屏幕
        menu.addItem(.separator())
        menu.addItem(item("重置绳子位置", #selector(resetRope)))
        let move = NSMenuItem(title: "移动到屏幕", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let current = RopePanel.shared.currentScreenIndex()
        var added = false
        for (i, s) in NSScreen.screens.enumerated() where i != current {
            let it = NSMenuItem(title: s.localizedName, action: #selector(pickScreen(_:)), keyEquivalent: "")
            it.target = self
            it.tag = i
            sub.addItem(it)
            added = true
        }
        if !added {
            let none = NSMenuItem(title: "没有其他屏幕", action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        }
        move.submenu = sub
        menu.addItem(move)

        menu.addItem(.separator())
        menu.addItem(item("设置…", #selector(openSettings), ","))
        menu.addItem(item("清空绳子", #selector(clearAll)))
        menu.addItem(.separator())
        menu.addItem(item("退出 PicRopeFM", #selector(quit), "q"))
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

    @objc private func resetRope() {
        RopePanel.shared.resetRope()
    }

    @objc private func pickScreen(_ sender: NSMenuItem) {
        RopePanel.shared.moveToScreenIndex(sender.tag)
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
