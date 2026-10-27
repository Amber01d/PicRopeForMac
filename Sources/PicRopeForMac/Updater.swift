import AppKit

/// 轻量更新检查：读取 GitHub Releases 最新版本，与当前版本比较
enum Updater {
    static let repo = "Amber01d/PicRopeForMac"
    static let releasesURL = "https://github.com/Amber01d/PicRopeForMac/releases"

    /// 当前应用版本（读 Info.plist，裸二进制回退 0.1.0）
    static var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0.1.0"
        return v
    }

    struct ReleaseInfo {
        let tag: String          // 如 v0.2.0
        let notes: String        // 更新说明
        let pageURL: String      // Release 页面链接
    }

    /// 拉取最新 Release（完成后回主线程回调）
    static func fetchLatest(completion: @escaping (Result<ReleaseInfo, Error>) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            completion(.failure(UpdaterError.badURL))
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let data,
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = obj["tag_name"] as? String,
                      let pageURL = obj["html_url"] as? String else {
                    completion(.failure(UpdaterError.noRelease))
                    return
                }
                let notes = obj["body"] as? String ?? ""
                completion(.success(ReleaseInfo(tag: tag, notes: notes, pageURL: pageURL)))
            }
        }.resume()
    }

    /// 语义化版本比较：tag 是否比 current 新（忽略 v / PRFM 等非数字前缀）
    static func isNewer(_ tag: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            // 去掉开头非数字前缀（v、PRFM 等）后按 . 切分
            let trimmed = s.drop(while: { !$0.isNumber })
            return trimmed.split(separator: ".")
                .map { Int($0) ?? 0 }
        }
        let a = parts(tag), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    enum UpdaterError: LocalizedError {
        case badURL, noRelease
        var errorDescription: String? {
            switch self {
            case .badURL: return "更新地址无效"
            case .noRelease: return "没有可用的 Release（或网络不可达）"
            }
        }
    }

    /// 检查并弹结果框（主动检查用）
    static func checkAndPrompt() {
        fetchLatest { result in
            switch result {
            case .success(let info):
                if isNewer(info.tag, than: currentVersion) {
                    let alert = NSAlert()
                    alert.messageText = "发现新版本 \(info.tag)（当前 \(currentVersion)）"
                    alert.informativeText = info.notes.isEmpty ? "是否前往下载？" : info.notes
                    alert.addButton(withTitle: "前往下载")
                    alert.addButton(withTitle: "稍后")
                    if alert.runModal() == .alertFirstButtonReturn {
                        if let url = URL(string: info.pageURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = "已是最新版本 \(currentVersion)"
                    alert.runModal()
                }
            case .failure(let error):
                let alert = NSAlert()
                alert.messageText = "检查更新失败"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    /// 静默检查（启动时自动检查用，仅在有新版本时提示）
    static func checkQuietly() {
        fetchLatest { result in
            if case .success(let info) = result, isNewer(info.tag, than: currentVersion) {
                checkAndPrompt()
            }
        }
    }
}
