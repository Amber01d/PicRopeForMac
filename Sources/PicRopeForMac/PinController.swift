import AppKit

/// 桌面贴图：置顶小窗，可拖动、滚轮缩放、右键关闭
final class PinController {
    static let shared = PinController()
    private var windows: [NSWindow] = []

    private init() {}

    func pin(item: CaptureItem) {
        let image = item.image
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)
        let maxW = screen.width * 0.5
        var size = image.size
        if size.width > maxW {
            size.height *= maxW / size.width
            size.width = maxW
        }

        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: screen.midX - size.width / 2,
                                                                   y: screen.midY - size.height / 2),
                                                  size: size),
                              styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .utilityWindow

        let pinView = PinImageView(frame: NSRect(origin: .zero, size: size), image: image, item: item)
        window.contentView = pinView
        window.orderFrontRegardless()
        windows.append(window)
    }

    func close(_ window: NSWindow) {
        window.orderOut(nil)
        windows.removeAll { $0 == window }
    }
}

/// 贴图内容视图：滚轮缩放、右键菜单
final class PinImageView: NSImageView {
    private let item: CaptureItem
    private let pinWindow: NSWindow

    init(frame: NSRect, image: NSImage, item: CaptureItem) {
        self.item = item
        self.pinWindow = NSWindow()
        super.init(frame: frame)
        // 借用 contentView 引用不可行，改为通过 window 查找
        self.image = image
        self.imageScaling = .scaleProportionallyUpOrDown
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    /// 按住图片拖动整个贴图窗口；双击关闭贴图
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            if let window = self.window {
                PinController.shared.close(window)
            }
            return
        }
        window?.performDrag(with: event)
    }

    /// 滚轮缩放（以图片中心点为锚点，中心不动）
    override func scrollWheel(with event: NSEvent) {
        guard let window = self.window else { return }
        let factor = event.deltaY > 0 ? 1.1 : 1 / 1.1
        let newW = max(60, min(window.frame.width * factor, 6000))
        let newH = newW / aspect
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        window.setFrame(NSRect(x: center.x - newW / 2,
                                y: center.y - newH / 2,
                                width: newW, height: newH), display: true)
    }

    private var aspect: CGFloat {
        guard let img = image, img.size.height > 0 else { return 1 }
        return img.size.width / img.size.height
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "复制", action: #selector(copyAction), keyEquivalent: "")
        copyItem.target = self
        let closeItem = NSMenuItem(title: "关闭贴图", action: #selector(closeAction), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(copyItem)
        menu.addItem(closeItem)
        return menu
    }

    @objc private func copyAction() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item.image])
        ClipboardMonitorBridge.shared.markSelfWrite()
        LightNotice.show("已复制")
    }

    @objc private func closeAction() {
        if let window = self.window {
            PinController.shared.close(window)
        }
    }
}
