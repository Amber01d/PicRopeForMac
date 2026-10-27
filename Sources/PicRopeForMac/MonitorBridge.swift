import AppKit

/// 监视器总调度：按设置启停剪贴板/文件夹监听
final class ClipboardMonitorBridge {
    static let shared = ClipboardMonitorBridge()

    let clipboard = ClipboardMonitor()
    let folder = FolderMonitor()

    private init() {}

    func start() { applySettings() }

    func applySettings() {
        if Settings.clipboardEnabled {
            clipboard.start()
        } else {
            clipboard.stop()
        }
        if Settings.folderEnabled {
            folder.watch(path: Settings.folderPath)
        } else {
            folder.stop()
        }
    }

    /// 自己往剪贴板写图后调用，避免监听器把刚复制的图又收回来
    func markSelfWrite() {
        clipboard.ignoreCurrentCount()
    }
}
