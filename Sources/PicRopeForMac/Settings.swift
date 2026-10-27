import AppKit

/// 用户设置（UserDefaults 持久化）
enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let clipboardEnabled = "clipboardEnabled"       // 剪贴板收集开关
        static let folderEnabled = "folderEnabled"             // 文件夹监听开关
        static let folderPath = "folderPath"                   // 监听目录
        static let ropeAlwaysVisible = "ropeAlwaysVisible"     // 绳子常驻屏幕
        static let ropeTransparent = "ropeTransparent"          // 背景全透明（只留绳子和截图）
        static let ropeOffsetX = "ropeOffsetX"                  // 绳子水平偏移（相对默认位置）
        static let ropeOffsetY = "ropeOffsetY"                  // 绳子垂直偏移（正值向下）
        static let ropeScreenIndex = "ropeScreenIndex"          // 绳子所在屏幕序号
        static let defaultSide = "defaultSide"                    // 默认截图卡片大小（pt）
    }

    /// 剪贴板收集（核心功能，默认开启）
    static var clipboardEnabled: Bool {
        get { defaults.object(forKey: Key.clipboardEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.clipboardEnabled) }
    }

    /// 文件夹监听（默认关闭，需用户自行配置路径）
    static var folderEnabled: Bool {
        get { defaults.object(forKey: Key.folderEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.folderEnabled) }
    }

    /// 监听目录，默认跟随系统截屏目录（自动识别中英文本地化目录名）
    static var folderPath: String {
        get {
            if let p = defaults.string(forKey: Key.folderPath), !p.isEmpty { return p }
            return Settings.defaultScreenshotsDir
        }
        set { defaults.set(newValue, forKey: Key.folderPath) }
    }

    /// 系统截屏目录：优先用户自定义位置，其次本地化目录名（屏幕截图/Screenshots）
    static var defaultScreenshotsDir: String {
        if let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            return (custom as NSString).expandingTildeInPath
        }
        let home = NSHomeDirectory()
        for name in ["屏幕截图", "Screenshots"] {
            let p = home + "/Pictures/" + name
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue { return p }
        }
        return home + "/Pictures/Screenshots"
    }

    /// 绳子常驻屏幕（不自动收起）
    static var ropeAlwaysVisible: Bool {
        get { defaults.object(forKey: Key.ropeAlwaysVisible) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.ropeAlwaysVisible) }
    }

    /// 背景全透明：只保留绳子和截图本体
    static var ropeTransparent: Bool {
        get { defaults.object(forKey: Key.ropeTransparent) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.ropeTransparent) }
    }

    /// 绳子水平偏移（相对屏幕顶部默认位置）
    static var ropeOffsetX: Double {
        get { defaults.double(forKey: Key.ropeOffsetX) }
        set { defaults.set(newValue, forKey: Key.ropeOffsetX) }
    }

    /// 绳子垂直偏移（正值向下）
    static var ropeOffsetY: Double {
        get { defaults.double(forKey: Key.ropeOffsetY) }
        set { defaults.set(newValue, forKey: Key.ropeOffsetY) }
    }

    /// 绳子所在屏幕序号（NSScreen.screens 下标，默认 0）
    static var ropeScreenIndex: Int {
        get {
            let v = defaults.integer(forKey: Key.ropeScreenIndex)
            return v
        }
        set { defaults.set(newValue, forKey: Key.ropeScreenIndex) }
    }

    /// 默认截图卡片大小（pt，40 ~ 240，基准 84）
    /// 只改变基准大小，不影响数量过多时的自动缩小
    static var defaultSide: Double {
        get {
            let v = defaults.double(forKey: Key.defaultSide)
            return v == 0 ? 84.0 : min(240.0, max(40.0, v))
        }
        set { defaults.set(min(240.0, max(40.0, newValue)), forKey: Key.defaultSide) }
    }
}