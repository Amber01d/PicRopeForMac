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
    private var sideField: NSTextField!
    private var sideStepper: NSStepper!

    /// 草稿：确定前只改这里
    private var draft = Draft()

    private struct Draft {
        var clipboardEnabled = Settings.clipboardEnabled
        var folderEnabled = Settings.folderEnabled
        var folderPath = Settings.folderPath
        var ropeAlwaysVisible = Settings.ropeAlwaysVisible
        var ropeTransparent = Settings.ropeTransparent
        var defaultSide = Settings.defaultSide
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

        let sizeLabel = NSTextField(labelWithString: "默认截图卡片大小：")
        sizeLabel.font = .systemFont(ofSize: 13)
        sizeLabel.sizeToFit()
        sizeLabel.frame.origin = NSPoint(x: x, y: row(244) + 4)
        content.addSubview(sizeLabel)

        sideField = NSTextField(frame: NSRect(x: x + 130, y: row(248), width: 56, height: 24))
        sideField.alignment = .center
        sideField.target = self
        sideField.action = #selector(fieldChanged)
        content.addSubview(sideField)

        sideStepper = NSStepper(frame: NSRect(x: x + 192, y: row(248), width: 60, height: 24))
        sideStepper.minValue = 40
        sideStepper.maxValue = 240
        sideStepper.increment = 8
        sideStepper.valueWraps = false
        sideStepper.target = self
        sideStepper.action = #selector(stepperChanged)
        content.addSubview(sideStepper)

        let sizeTip = NSTextField(labelWithString: "pt（40–240，仅基准大小，数量多时仍会自动缩小）")
        sizeTip.font = .systemFont(ofSize: 11)
        sizeTip.textColor = .secondaryLabelColor
        sizeTip.frame = NSRect(x: x, y: row(274), width: w - 48, height: 18)
        content.addSubview(sizeTip)

        let tip = NSTextField(labelWithString: "绳子操作：拖动空白处上下移动绳子；右键空白处可重置位置")
        tip.font = .systemFont(ofSize: 11)
        tip.textColor = .secondaryLabelColor
        tip.frame = NSRect(x: x, y: row(294), width: w - 48, height: 18)
        content.addSubview(tip)

        // 恢复默认 / 确定 / 取消
        let reset = NSButton(title: "初始化设置", target: self, action: #selector(resetSettings))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: x, y: 16, width: 96, height: 28)
        content.addSubview(reset)

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
        sideField.stringValue = String(Int(draft.defaultSide))
        sideStepper.doubleValue = draft.defaultSide
    }

    // MARK: - 草稿更新（不生效）

    @objc private func draftChanged() {
        draft.clipboardEnabled = clipboardCheck.state == .on
        draft.folderEnabled = folderCheck.state == .on
        draft.folderPath = pathField.stringValue
        draft.ropeAlwaysVisible = alwaysCheck.state == .on
        draft.ropeTransparent = transparentCheck.state == .on
    }

    /// 步进器：以步进器为准，同步输入框
    @objc private func stepperChanged() {
        draft.defaultSide = sideStepper.doubleValue
        sideField.stringValue = String(Int(sideStepper.doubleValue))
    }

    /// 输入框：解析数值（非法/越界自动钳制），同步步进器
    @objc private func fieldChanged() {
        let v = Double(sideField.stringValue) ?? draft.defaultSide
        draft.defaultSide = min(240, max(40, v))
        sideStepper.doubleValue = draft.defaultSide
        sideField.stringValue = String(Int(draft.defaultSide))
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
        Settings.defaultSide = draft.defaultSide

        // 应用
        ClipboardMonitorBridge.shared.applySettings()
        RopePanel.shared.applySettings()
        RopePanel.shared.reloadIfShown()
        if !Settings.ropeAlwaysVisible {
            RopePanel.shared.hide()
        }
        window.orderOut(nil)
    }

    @objc private func cancelAndClose() {
        draft = Draft()
        window.orderOut(nil)
    }

    /// 初始化设置：全部恢复默认值并立即生效
    @objc private func resetSettings() {
        Settings.clipboardEnabled = true
        Settings.folderEnabled = false
        Settings.folderPath = Settings.defaultScreenshotsDir
        Settings.ropeAlwaysVisible = false
        Settings.ropeTransparent = false
        Settings.ropeOffsetX = 0
        Settings.ropeOffsetY = 0
        Settings.thumbScale = 1.0
        Settings.defaultSide = 84

        // 立即应用
        ClipboardMonitorBridge.shared.applySettings()
        RopePanel.shared.applySettings()
        RopePanel.shared.reloadIfShown()
        RopePanel.shared.hide()

        // 刷新草稿与 UI
        draft = Draft()
        reloadUI()
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
