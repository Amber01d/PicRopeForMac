import AppKit

/// 剪贴板监听（核心通道：非系统原生截图工具都走剪贴板）
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    /// 自己执行“单击复制”造成的 changeCount，跳过防止自我循环
    private var ignoredCounts = Set<Int>()
    private let pasteboard = NSPasteboard.general

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 由“单击复制”调用方登记：本次 changeCount 是自己写的，不要回收
    func ignoreCurrentCount() {
        ignoredCounts.insert(pasteboard.changeCount)
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard !ignoredCounts.contains(count) else { return }
        ignoredCounts = ignoredCounts.filter { $0 > count }
        guard let item = readImage() else { return }
        CaptureStore.shared.add(item)
    }

    private func readImage() -> CaptureItem? {
        guard let types = pasteboard.types else { return nil }
        // 常见截图工具写入的是 PNG/TIFF
        let preferred: [NSPasteboard.PasteboardType] = [.png, .tiff, .URL]
        for type in preferred where types.contains(type) {
            if type == .URL,
               let url = pasteboard.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL],
               let fileURL = url.first(where: { $0.isFileURL }),
               let data = try? Data(contentsOf: fileURL),
               let item = CaptureItem(pngData: data, source: "剪贴板·文件") {
                return item
            } else if type != .URL, let data = pasteboard.data(forType: type) {
                if let item = CaptureItem(pngData: data, source: "剪贴板") {
                    return item
                }
            }
        }
        // 兜底：文件承诺/Flickr 等场景
        if let data = pasteboard.data(forType: .png) {
            return CaptureItem(pngData: data, source: "剪贴板")
        }
        return nil
    }
}
