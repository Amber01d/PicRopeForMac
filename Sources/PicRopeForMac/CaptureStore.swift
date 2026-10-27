import AppKit
import Combine

/// 一张被“挂上绳子”的截图
final class CaptureItem: Identifiable {
    let id: UUID
    let image: NSImage        // 展示用图像
    let data: Data            // 原始 PNG 数据（复制/拖拽/落盘用）
    let hash: String          // 内容去重
    let source: String        // 来源描述："剪贴板" 或文件路径
    let createdAt: Date
    /// 从磁盘恢复时保留原文件名，否则删除时对不上文件
    private let storedFileName: String?
    var fileName: String {
        storedFileName ?? "\(Int(createdAt.timeIntervalSince1970))-\(id.uuidString).png"
    }

    init?(image: NSImage, source: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        self.id = UUID()
        self.image = image
        self.data = png
        self.hash = CaptureItem.digest(png)
        self.source = source
        self.createdAt = Date()
        self.storedFileName = nil
    }

    init?(pngData: Data, source: String, createdAt: Date = Date(), fileName: String? = nil) {
        guard let image = NSImage(data: pngData) else { return nil }
        self.id = UUID()
        self.image = image
        self.data = pngData
        self.hash = CaptureItem.digest(pngData)
        self.source = source
        self.createdAt = createdAt
        self.storedFileName = fileName
    }

    private static func digest(_ data: Data) -> String {
        String(format: "%x%x%x%x", data.count,
               data.prefix(8).reduce(0) { $0 &* 31 &+ Int($1) },
               data.dropFirst(data.count / 2).prefix(8).reduce(0) { $0 &* 31 &+ Int($1) },
               data.suffix(8).reduce(0) { $0 &* 31 &+ Int($1) })
    }
}

/// 全部截图的内存仓库 + 本地持久化（重启恢复）
final class CaptureStore {
    static let shared = CaptureStore()

    /// 截图落盘目录
    static var storeDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
            .appendingPathComponent("PicRopeForMac/captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private(set) var items: [CaptureItem] = []
    private let maxItems = 50   // 绳子只保留最近 50 张（对齐 PicRope 规则）
    private var hashes = Set<String>()
    private let queue = DispatchQueue(label: "PicRope.store")

    let changes = PassthroughSubject<Void, Never>()

    private init() {
        loadPersisted()
    }

    // MARK: - 持久化

    private func fileURL(_ item: CaptureItem) -> URL {
        CaptureStore.storeDir.appendingPathComponent(item.fileName)
    }

    /// 启动时从磁盘恢复
    private func loadPersisted() {
        let dir = CaptureStore.storeDir
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let sorted = names
            .filter { $0.hasSuffix(".png") }
            .sorted { $0 < $1 }   // 文件名前缀是时间戳，字典序即时间序
        var loaded: [CaptureItem] = []
        for name in sorted {
            let ts = Double(name.prefix { $0.isNumber }) ?? 0
            guard ts > 0,
                  let data = try? Data(contentsOf: dir.appendingPathComponent(name)),
                  let item = CaptureItem(pngData: data, source: "上次会话",
                                         createdAt: Date(timeIntervalSince1970: ts),
                                         fileName: name) else { continue }
            guard !hashes.contains(item.hash) else { continue }
            hashes.insert(item.hash)
            loaded.append(item)
        }
        // 只恢复最近 maxItems 张
        if loaded.count > maxItems {
            let drop = Array(loaded[0..<(loaded.count - maxItems)])
            drop.forEach { try? FileManager.default.removeItem(at: fileURL($0)) }
            loaded.removeFirst(loaded.count - maxItems)
        }
        items = loaded
    }

    /// 新增并落盘
    func add(_ item: CaptureItem) {
        var inserted = false
        queue.sync {
            guard !hashes.contains(item.hash) else { return }
            hashes.insert(item.hash)
            items.append(item)
            inserted = true
            NSLog("[PicRope] 挂上绳子: %@ (%d bytes)", item.source, item.data.count)
            try? item.data.write(to: fileURL(item))
            if items.count > maxItems {
                let overflow = items.count - maxItems
                let removed = Array(items[0..<overflow])
                items.removeFirst(overflow)
                removed.forEach { hashes.remove($0.hash) }
                // 淘汰的同时删除对应磁盘文件
                removed.forEach { try? FileManager.default.removeItem(at: fileURL($0)) }
            }
        }
        guard inserted else { return }
        changes.send()
        NotificationCenter.default.post(name: .picRopeItemAdded, object: nil)
    }

    /// 移除并删除磁盘文件
    func remove(_ item: CaptureItem) {
        queue.sync {
            items.removeAll { $0.id == item.id }
            hashes.remove(item.hash)
            try? FileManager.default.removeItem(at: fileURL(item))
        }
        changes.send()
    }

    /// 移除除指定图片外的所有图片（含本地缓存）
    func removeAll(except keep: CaptureItem) {
        queue.sync {
            let removed = items.filter { $0.id != keep.id }
            removed.forEach { try? FileManager.default.removeItem(at: fileURL($0)) }
            items = [keep]
            hashes = [keep.hash]
        }
        changes.send()
    }

    /// 清空绳子（同时清空本地缓存）
    func clear() {
        queue.sync {
            items.forEach { try? FileManager.default.removeItem(at: fileURL($0)) }
            items.removeAll()
            hashes.removeAll()
        }
        changes.send()
    }
}
