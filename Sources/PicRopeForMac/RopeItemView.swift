import AppKit

/// 绳子上的单个截图：固定正方形（中心裁剪，无视原比例）
/// 单击复制、双击钉桌面、右键菜单
final class RopeItemView: NSImageView {
    let item: CaptureItem
    /// 方块边长上限（放不下时会整体缩小）
    static let maxSide: CGFloat = 84
    private let side: CGFloat

    init(item: CaptureItem, side: CGFloat = RopeItemView.maxSide) {
        self.item = item
        self.side = side
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
        self.image = RopeItemView.squareCropped(item.image, side: side)
        self.imageScaling = .scaleProportionallyUpOrDown
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 3
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        // 悬停放大动画
        layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    /// 中心裁剪为正方形（无视原比例）
    private static func squareCropped(_ image: NSImage, side: CGFloat) -> NSImage {
        let s = min(image.size.width, image.size.height)
        let srcRect = NSRect(x: (image.size.width - s) / 2,
                             y: (image.size.height - s) / 2,
                             width: s, height: s)
        let cropped = NSImage(size: NSSize(width: side, height: side))
        cropped.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
                  from: srcRect, operation: .copy, fraction: 1)
        cropped.unlockFocus()
        return cropped
    }

    // MARK: - 单击复制 / 双击钉桌面
    // 注意：不调用 super 的鼠标事件处理，NSImageView 默认实现会吞掉后续事件

    override func mouseDown(with event: NSEvent) {
        // 保留钩子：目前单击/双击均在 mouseUp 处理
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            PinController.shared.pin(item: item)
        } else {
            copyToClipboard()
        }
    }

    func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item.image])
        ClipboardMonitorBridge.shared.markSelfWrite()
        LightNotice.show("已复制")
    }

    // MARK: - 悬停高亮（被选中提示）

    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        // 高亮：强调色边框 + 轻微放大
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 2
            layer?.transform = CATransform3DMakeScale(1.08, 1.08, 1)
        })
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
            layer?.borderWidth = 1
            layer?.transform = CATransform3DIdentity
        })
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: - 右键菜单

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(mi("复制", #selector(copyToClipboardMenu)))
        menu.addItem(mi("钉在桌面", #selector(pinMenu)))
        menu.addItem(mi("存储到…", #selector(saveMenu)))
        menu.addItem(.separator())
        menu.addItem(mi("删除此图片", #selector(removeMenu)))
        menu.addItem(mi("移除除此之外所有图片", #selector(removeOthersMenu)))
        menu.addItem(mi("删除绳子上所有图片", #selector(removeAllMenu)))
        return menu
    }

    private func mi(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc private func copyToClipboardMenu() { copyToClipboard() }
    @objc private func pinMenu() { PinController.shared.pin(item: item) }
    @objc private func removeMenu() { CaptureStore.shared.remove(item) }
    @objc private func removeOthersMenu() { CaptureStore.shared.removeAll(except: item) }
    @objc private func removeAllMenu() { CaptureStore.shared.clear() }

    @objc private func saveMenu() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "PicRope-\(Int(item.createdAt.timeIntervalSince1970)).png"
        if panel.runModal() == .OK, let url = panel.url {
            try? item.data.write(to: url)
        }
    }
}
