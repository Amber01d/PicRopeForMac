import AppKit

// 应用入口：菜单栏应用（accessory），不显示 Dock 图标
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
