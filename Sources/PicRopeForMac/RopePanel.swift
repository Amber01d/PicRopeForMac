import AppKit
import Combine

/// 屏幕上沿的“绳子”面板：中部下垂的曲线绳 + 从中心向两侧交替悬挂的正方形截图
final class RopePanel {
    static let shared = RopePanel()

    private var panel: NSPanel!
    private var scrollView: NSScrollView!
    private var canvas: RopeCanvas!
    private var container: NSView!
    private var cancellables = Set<AnyCancellable>()
    private var hideWork: DispatchWorkItem?

    private var isShown = false

    /// 布局常量（maxSide 读取用户设置的基准卡片大小）
    private enum Layout {
        static var maxSide: CGFloat { CGFloat(Settings.defaultSide) }  // 基准边长（用户可调）
        static let minSide: CGFloat = 28                    // 截图边长下限（再小就横向滚动）
        static let spacing: CGFloat = 16                    // 截图间距
        static let margin: CGFloat = 20                      // 左右边距
        static let sag: CGFloat = 30                          // 绳子中部下垂深度
        static let topPad: CGFloat = 16                       // 绳子两端距面板顶部
        static let pinH: CGFloat = 10                         // 衣夹高度
        static let bottomPad: CGFloat = 16                   // 底部留白
        static var panelHeight: CGFloat { topPad + sag + pinH + maxSide + bottomPad + 6 }
    }

    private init() {
        let screen = NSScreen.main!
        let size = NSSize(width: screen.frame.width, height: Layout.panelHeight)

        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.88).cgColor
        container.layer?.cornerRadius = 14
        self.container = container

        canvas = RopeCanvas(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        canvas.maxSide = Layout.maxSide
        canvas.minSide = Layout.minSide
        canvas.sag = Layout.sag
        canvas.topPad = Layout.topPad
        canvas.pinH = Layout.pinH
        canvas.margin = Layout.margin
        canvas.spacing = Layout.spacing

        scrollView = NSScrollView()
        scrollView.documentView = canvas
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        scrollView.automaticallyAdjustsContentInsets = false
        container.addSubview(scrollView)

        panel.contentView = container

        CaptureStore.shared.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.reposition()
        }
        reposition()
        reload()
    }

    /// 绳子锚定的屏幕（按设置，越界回退主屏）
    var anchorScreen: NSScreen {
        let screens = NSScreen.screens
        let idx = Settings.ropeScreenIndex
        if screens.indices.contains(idx) { return screens[idx] }
        return NSScreen.main ?? screens[0]
    }

    /// 绳子当前实际所在屏幕序号（按面板中心点命中判断）
    func currentScreenIndex() -> Int {
        let f = panel.frame
        let center = NSPoint(x: f.midX, y: f.midY)
        if let i = NSScreen.screens.firstIndex(where: { NSPointInRect(center, $0.frame) }) {
            return i
        }
        return 0
    }

    /// 切换到指定屏幕（保持相对顶部的垂直偏移）
    func moveToScreenIndex(_ index: Int) {
        let screens = NSScreen.screens
        guard screens.indices.contains(index) else { return }
        Settings.ropeScreenIndex = index
        Settings.ropeOffsetX = 0
        reposition()
        reload()
    }

    private func reposition() {
        let screen = anchorScreen
        // 默认贴屏幕顶部（避开刘海），叠加用户拖动偏移
        let y = screen.frame.maxY - screen.safeAreaInsets.top - Layout.panelHeight - Settings.ropeOffsetY
        panel.setFrameTopLeftPoint(NSPoint(x: screen.frame.minX + Settings.ropeOffsetX, y: y))
    }

    private func reload() {
        // 基准卡片大小变化时同步面板/容器尺寸
        let size = NSSize(width: panel.frame.width, height: Layout.panelHeight)
        if panel.frame.height != size.height {
            panel.setContentSize(size)
            container.frame = NSRect(origin: .zero, size: size)
            scrollView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        }
        canvas.maxSide = Layout.maxSide
        canvas.setFrameSize(NSSize(width: max(panel.frame.width, canvas.neededWidth),
                                   height: Layout.panelHeight))
        canvas.setItems(CaptureStore.shared.items.reversed())
    }

    /// 拖动移动绳子（只允许上下调节；dy 向上为正）
    func moveBy(dx: CGFloat, dy: CGFloat) {
        guard dy != 0 else { return }
        Settings.ropeOffsetX = 0   // 水平不生效，始终居中贴屏幕左沿
        Settings.ropeOffsetY -= Double(dy)
        reposition()
    }

    /// 重置绳子位置（仅垂直）
    func resetRope() {
        Settings.ropeOffsetX = 0
        Settings.ropeOffsetY = 0
        reposition()
        reload()
    }

    func show() {
        guard !isShown else { return }
        isShown = true
        hideWork?.cancel()
        reload()
        reposition()
        panel.orderFrontRegardless()
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        panel.orderOut(nil)
    }

    /// 鼠标离开后延迟收起（避免误触）；常驻模式下不自动收起，但手动隐藏始终有效
    func scheduleHide() {
        guard !Settings.ropeAlwaysVisible else { return }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func cancelHide() { hideWork?.cancel() }

    /// 外部触发：按当前设置刷新尺寸与布局（设置确定后调用）
    func reloadIfShown() {
        reload()
        reposition()
    }

    /// 设置变更后应用：常驻 / 透明背景
    func applySettings() {
        if Settings.ropeTransparent {
            // 背景全透明：只留绳子和截图本体
            container.layer?.backgroundColor = NSColor.clear.cgColor
            panel.hasShadow = false
        } else {
            container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.88).cgColor
            panel.hasShadow = true
        }
        canvas.needsDisplay = true
    }
}

/// 绳子画布：绘制带材质的下垂曲线绳 + 衣夹 + 从中心交替向外悬挂的正方形截图
final class RopeCanvas: NSView {
    var maxSide: CGFloat = 84
    var minSide: CGFloat = 28
    var sag: CGFloat = 30
    var topPad: CGFloat = 16
    var pinH: CGFloat = 10
    var margin: CGFloat = 20
    var spacing: CGFloat = 16

    private var items: [CaptureItem] = []
    private var itemFrames: [NSRect] = []
    private var currentSide: CGFloat = 84
    private var trackingArea: NSTrackingArea?

    /// 按当前项数计算方块边长：放不下就缩小，缩到下限改为横向滚动
    private func computeSide() -> CGFloat {
        let count = items.count
        guard count > 0 else { return maxSide }
        let avail = bounds.width - margin * 2
        let need = CGFloat(count) * maxSide + CGFloat(count - 1) * spacing
        if need <= avail { return maxSide }
        let fitted = floor((avail - CGFloat(count - 1) * spacing) / CGFloat(count))
        return max(minSide, min(maxSide, fitted))
    }

    /// 所需画布宽度（含滚动兜底时的极小尺寸估算）
    var neededWidth: CGFloat {
        guard !items.isEmpty else { return 0 }
        let side = computeSide()
        return margin * 2 + CGFloat(items.count) * side + CGFloat(items.count - 1) * spacing
    }

    func setItems(_ items: [CaptureItem]) {
        self.items = items
        currentSide = computeSide()
        subviews.forEach { $0.removeFromSuperview() }
        for item in items {
            addSubview(RopeItemView(item: item, side: currentSide))
        }
        needsLayout = true
        needsDisplay = true
    }

    // MARK: - 绳子曲线

    /// 抛物线：u∈[0,1] → 下垂量 4·sag·u(1-u)，峰值 sag 在中点
    private func ropeY(atX x: CGFloat) -> CGFloat {
        let u = min(max(x / max(bounds.width, 1), 0), 1)
        let drop = 4 * sag * u * (1 - u)
        return bounds.height - topPad - drop
    }

    /// 生成绳曲线，offset 为 y 方向平移（用于投影/高光分层）
    private func ropePath(offset: CGFloat = 0) -> NSBezierPath {
        let path = NSBezierPath()
        let base = bounds.height - topPad + offset
        path.move(to: NSPoint(x: 0, y: base))
        let midY = base - sag
        path.curve(to: NSPoint(x: bounds.width, y: base),
                   controlPoint1: NSPoint(x: bounds.width * 0.25, y: midY + 2),
                   controlPoint2: NSPoint(x: bounds.width * 0.75, y: midY + 2))
        return path
    }

    // MARK: - 布局（从中心向两侧交替延伸）

    /// 第 i 个（i=0 最新）的槽位偏移：0, -1, +1, -2, +2 ...
    private func slotOffset(_ i: Int) -> CGFloat {
        if i == 0 { return 0 }
        return i % 2 == 1 ? -CGFloat((i + 1) / 2) : CGFloat(i / 2)
    }

    override func layout() {
        super.layout()
        itemFrames.removeAll()
        let cx = bounds.width / 2
        for (i, view) in subviews.enumerated() {
            let x = cx + slotOffset(i) * (currentSide + spacing) - currentSide / 2
            let ry = ropeY(atX: x + currentSide / 2)
            // 图顶挂在绳下方（夹住衣夹底端），沿曲线高度错落
            let frame = NSRect(x: x, y: ry - pinH - currentSide, width: currentSide, height: currentSide)
            view.frame = frame
            itemFrames.append(frame)
        }
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawRope()
        drawPins()
        if items.isEmpty {
            drawHint()
        }
    }

    /// 绳子材质：阴影线 + 麻绳主体 + 高光 + 捻纹虚线，四层叠出立体感
    private func drawRope() {
        // 1. 投影
        let shadow = ropePath(offset: -1.5)
        shadow.lineWidth = 5
        shadow.lineCapStyle = .round
        NSColor.black.withAlphaComponent(0.15).setStroke()
        shadow.stroke()

        // 2. 主体（麻棕）
        let body = ropePath()
        body.lineWidth = 5
        body.lineCapStyle = .round
        NSColor(calibratedRed: 0.62, green: 0.48, blue: 0.33, alpha: 1).setStroke()
        body.stroke()

        // 3. 暗部（下沿，拧股阴影）
        let dark = ropePath(offset: -1.2)
        dark.lineWidth = 2
        dark.lineCapStyle = .round
        NSColor(calibratedRed: 0.42, green: 0.30, blue: 0.18, alpha: 0.8).setStroke()
        dark.stroke()

        // 4. 高光（上沿）
        let hi = ropePath(offset: 1.4)
        hi.lineWidth = 1.5
        hi.lineCapStyle = .round
        NSColor(calibratedWhite: 1.0, alpha: 0.55).setStroke()
        hi.stroke()

        // 5. 捻纹（斜向短虚线模拟纤维股）
        let twist = ropePath()
        twist.lineWidth = 1
        twist.setLineDash([1.5, 3.5], count: 2, phase: 0)
        NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.10, alpha: 0.45).setStroke()
        twist.stroke()

        // 6. 两端固定结
        for x in [CGFloat(0), bounds.width] {
            let knot = NSBezierPath(ovalIn: NSRect(x: x - 4, y: bounds.height - topPad - 4, width: 8, height: 8))
            NSColor(calibratedRed: 0.45, green: 0.33, blue: 0.20, alpha: 1).setFill()
            knot.fill()
        }
    }

    /// 衣夹：每个挂点画一个小木夹
    private func drawPins() {
        for frame in itemFrames {
            let x = frame.midX
            let ry = frame.maxY + pinH - 2
            let pinRect = NSRect(x: x - 4, y: ry - pinH + 2, width: 8, height: pinH)
            // 木夹体
            let pin = NSBezierPath(roundedRect: pinRect, xRadius: 2, yRadius: 2)
            NSColor(calibratedRed: 0.82, green: 0.68, blue: 0.50, alpha: 1).setFill()
            pin.fill()
            // 夹口细缝
            let gap = NSBezierPath()
            gap.move(to: NSPoint(x: x, y: pinRect.minY + 2))
            gap.line(to: NSPoint(x: x, y: pinRect.maxY - 1))
            gap.lineWidth = 1
            NSColor(calibratedRed: 0.45, green: 0.33, blue: 0.20, alpha: 0.7).setStroke()
            gap.stroke()
        }
    }

    private func drawHint() {
        let s = "暂无截图 —— 复制一张图片或截个图试试"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        str.draw(in: NSRect(x: (bounds.width - 220) / 2,
                            y: bounds.height - topPad - 40, width: 260, height: 18))
    }

    // MARK: - 空白处拖动移动绳子 / 右键缩放菜单

    private var lastMovePoint: NSPoint?

    /// 悬停时显示移动光标（张开的抓手）
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        // 点击空白处（非截图子视图）开始拖动绳子
        lastMovePoint = NSEvent.mouseLocation
        // 按住后变为抓住的手型
        NSCursor.closedHand.push()    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = lastMovePoint else { return }
        let now = NSEvent.mouseLocation
        // 只允许上下调节，忽略水平位移
        RopePanel.shared.moveBy(dx: 0, dy: now.y - start.y)
        lastMovePoint = now
    }

    override func mouseUp(with event: NSEvent) {
        lastMovePoint = nil
        NSCursor.closedHand.pop()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(mi("重置绳子位置", #selector(resetAll)))

        // 移动到屏幕：列出除当前屏幕外的所有屏幕
        let moveItem = NSMenuItem(title: "移动到屏幕", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let current = RopePanel.shared.currentScreenIndex()
        var added = false
        for (i, s) in NSScreen.screens.enumerated() where i != current {
            let item = NSMenuItem(title: s.localizedName, action: #selector(pickScreen(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            sub.addItem(item)
            added = true
        }
        if !added {
            let none = NSMenuItem(title: "没有其他屏幕", action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        }
        moveItem.submenu = sub
        menu.addItem(moveItem)
        return menu
    }

    private func mi(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc private func resetAll() { RopePanel.shared.resetRope() }
    @objc private func pickScreen(_ sender: NSMenuItem) {
        RopePanel.shared.moveToScreenIndex(sender.tag)
    }

    // MARK: - 悬停跟踪（进入绳子不收起，离开收起）

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        RopePanel.shared.cancelHide()
    }

    override func mouseExited(with event: NSEvent) {
        RopePanel.shared.scheduleHide()
    }

    // 滚轮横向浏览
    override func scrollWheel(with event: NSEvent) {
        if abs(event.deltaX) > 0.1, let target = enclosingScrollView {
            let clip = target.contentView
            let pt = clip.bounds.origin
            clip.scroll(to: NSPoint(x: max(0, pt.x - event.deltaX * 2), y: 0))
        } else {
            super.scrollWheel(with: event)
        }
    }
}
