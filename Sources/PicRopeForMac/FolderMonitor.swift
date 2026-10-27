import AppKit


/// 文件夹监听（辅助通道）：启动时建立基线列表，运行时定时轮询，仅新增图片挂上绳子
final class FolderMonitor {
    private var timer: Timer?
    /// 基线：启动/开始监听时目录中已存在的图片列表（不会挂上绳子）
    private var baselineFiles: Set<String> = []
    private var path: String = ""

    /// 轮询间隔（秒）
    private let pollInterval: TimeInterval = 1.0

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "bmp", "gif", "tif", "tiff", "webp", "heic"]

    func watch(path: String) {
        stop()
        // 去除首尾空白（手输路径常见问题）
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        self.path = path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            NSLog("[PicRope] 监听目录不存在: %@（请检查设置中的路径）", path)
            return
        }
        // 第一步：启动时读取目录，建立基线（已有图片不挂上）
        baselineFiles = Set(currentImageFiles())
        NSLog("[PicRope] 开始监听目录: %@（基线 %d 张，仅新增图片会挂上绳子）", path, baselineFiles.count)
        // 第二步：运行时定时轮询，与基线比较
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        baselineFiles.removeAll()
    }

    /// 轮询：与基线比较，新增图片挂上绳子
    private func poll() {
        let files = currentImageFiles()
        let newFiles = files.filter { !baselineFiles.contains($0) }
        guard !newFiles.isEmpty else { return }
        // 新文件可能有写入延迟，稍候再校验大小稳定后挂上
        for file in newFiles {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: file),
                  let size = attrs[.size] as? Int, size > 0 else {
                continue    // 文件还没写完，下轮再看
            }
            if let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
               let item = CaptureItem(pngData: data, source: "文件夹·\(URL(fileURLWithPath: file).lastPathComponent)") {
                CaptureStore.shared.add(item)
            }
            // 挂上（或读取失败）后并入基线，避免反复尝试
            baselineFiles.insert(file)
        }
    }

    private func currentImageFiles() -> [String] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }
        return names
            .filter { FolderMonitor.imageExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted { $0 < $1 }
            .map { path + "/" + $0 }
    }
}
