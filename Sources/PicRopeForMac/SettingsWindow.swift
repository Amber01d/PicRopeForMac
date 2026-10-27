import AppKit
import ServiceManagement

/// 设置窗口：所有改动先进草稿，点「确定」才生效
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow!

    private var clipboardCheck: NSButton!
    private var folderCheck: NSButton!
    private var pathField: NSTextField!
    private var alwaysCheck: NSButton!
    private var transparentCheck: NSButton!
    private var loginCheck: NSButton!

    /// 草稿：确定前只改这里
    private var draft = Draft()

    private struct Draft {
        var clipboardEnabled = Settings.clipboardEnabled
        var folderEnabled = Settings.folderEnabled
        var folderPath = Settings.folderPath
        var ropeAlwaysVisible = Settings.ropeAlwaysVisible
        var ropeTransparent = Settings.ropeTransparent
    }

    private init() {
        let w = 480.0, h = 372.0
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        window.title = "PicRope 设置"
        window.level = .floating
        window.isReleasedWhenClosed = false

        let content = window.contentView!
        let x = 24.0

        func row(_ y: CGFloat) -> CGFloat { h - y }

        clipboardCheck = NSButton(checkboxWithTitle: "剪贴板收集（推荐：微信/iShot/Snipaste 等截图工具）",
                                  target: self, action: #selector(draftChanged))
        clipboardCheck.frame = NSRect(x: x, y: row(44), width: w - 48, height: 24)
        content.addSubview(clipboardCheck)

        folderCheck = NSButton(checkboxWithTitle: "监听文件夹内新增图片",
                               target: self, action: #selector(draftChanged))
        folderCheck.frame = NSRect(x: x, y: row(76), width: w - 48, height: 24)
        content.addSubview(folderCheck)

        pathField = NSTextField(frame: NSRect(x: x, y: row(108), width: w - 140, height: 24))
        pathField.placeholderString = "选择要监听的文件夹"
        pathField.target = self
        pathField.action = #selector(draftChanged)
        content.addSubview(pathField)

        let pick = NSButton(title: "选择…", target: self, action: #selector(pickFolder))
        pick.bezelStyle = .rounded
        pick.frame = NSRect(x: w - 104, y: row(110), width: 80, height: 28)
        content.addSubview(pick)

        alwaysCheck = NSButton(checkboxWithTitle: "绳子常驻屏幕（不自动收起）",
                               target: self, action: #selector(draftChanged))
        alwaysCheck.frame = NSRect(x: x, y: row(148), width: w - 48, height: 24)
        content.addSubview(alwaysCheck)

        transparentCheck = NSButton(checkboxWithTitle: "背景全透明（只保留绳子和截图本体）",
                                     target: self, action: #selector(draftChanged))
        transparentCheck.frame = NSRect(x: x, y: row(180), width: w - 48, height: 24)
        content.addSubview(transparentCheck)

        loginCheck = NSButton(checkboxWithTitle: "开机自动启动（立即生效，无需确定）",
                              target: self, action: #selector(toggleLogin))
        loginCheck.frame = NSRect(x: x, y: row(212), width: w - 48, height: 24)
        loginCheck.state = SMAppService.mainApp.status == .enabled ? .on : .off
        content.addSubview(loginCheck)

        let tip = NSTextField(labelWithString: "绳子操作：拖动空白处移动位置；右键空白处可缩放截图 / 重置")
        tip.font = .systemFont(ofSize: 11)
        tip.textColor = .secondaryLabelColor
        tip.frame = NSRect(x: x, y: row(248), width: w - 48, height: 18)
        content.addSubview(tip)

        // 确定 / 取消
        let ok = NSButton(title: "确定", target: self, action: #selector(applyAndClose))
        ok.bezelStyle = .rounded
        ok.keyEquivalent = "\r"
        ok.frame = NSRect(x: w - 190, y: 16, width: 80, height: 28)
        content.addSubview(ok)

        let cancel = NSButton(title: "取消", target: self, action: #selector(cancelAndClose))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: w - 104, y: 16, width: 80, height: 28)
        content.addSubview(cancel)

        reloadUI()
        centerOnScreen()
    }

    private func centerOnScreen() {
        if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - window.frame.width / 2,
                                          y: screen.visibleFrame.midY - window.frame.height / 2))
        }
    }

    func show() {
        draft = Draft()
        reloadUI()
        centerOnScreen()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 草稿与 UI 同步
    private func reloadUI() {
        clipboardCheck.state = draft.clipboardEnabled ? .on : .off
        folderCheck.state = draft.folderEnabled ? .on : .off
        pathField.stringValue = draft.folderPath
        alwaysCheck.state = draft.ropeAlwaysVisible ? .on : .off
        transparentCheck.state = draft.ropeTransparent ? .on : .off
    }

    // MARK: - 草稿更新（不生效）

    @objc private func draftChanged() {
        draft.clipboardEnabled = clipboardCheck.state == .on
        draft.folderEnabled = folderCheck.state == .on
        draft.folderPath = pathField.stringValue
        draft.ropeAlwaysVisible = alwaysCheck.state == .on
        draft.ropeTransparent = transparentCheck.state == .on
    }

    @objc private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            pathField.stringValue = url.path
            draftChanged()
        }
    }

    // MARK: - 确定 / 取消

    @objc private func applyAndClose() {
        draftChanged()
        Settings.clipboardEnabled = draft.clipboardEnabled
        Settings.folderEnabled = draft.folderEnabled
        Settings.folderPath = draft.folderPath
        Settings.ropeAlwaysVisible = draft.ropeAlwaysVisible
        Settings.ropeTransparent = draft.ropeTransparent

        // 应用
        ClipboardMonitorBridge.shared.applySettings()
        RopePanel.shared.applySettings()
        if !Settings.ropeAlwaysVisible {
            RopePanel.shared.hide()
        }
        window.orderOut(nil)
    }

    @objc private func cancelAndClose() {
        draft = Draft()
        window.orderOut(nil)
    }

    // MARK: - 开机自启动（系统登录项，立即生效）

    @objc private func toggleLogin() {
        let on = loginCheck.state == .on
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 以 swift run / 裸二进制方式启动时无法注册，需要 .app 包运行
            loginCheck.state = .off
            let alert = NSAlert()
            alert.messageText = "开机自启动设置失败"
            alert.informativeText = "请通过 PicRopeForMac.app 启动后设置（裸二进制无法注册登录项）。\n\(error.localizedDescription)"
            alert.runModal()
        }
    }
}
