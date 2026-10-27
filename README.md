# PicRopeForMac

[PicRope](https://github.com/Renly1994/PicRope)（Windows 截图暂存/贴图工具）的 Mac 版重实现。
原生 Swift + AppKit，零第三方依赖，单包不到 100KB。

## 功能

### 收集（两条通道）
- **剪贴板收集（核心通道，默认开启）**：任何写入剪贴板的截图工具（iShot、Snipaste、微信 Alt+A、`Ctrl+Cmd+Shift+4` 等）截完自动挂上绳子，内容哈希去重、单击复制自我回收保护
- **文件夹监听（辅助通道，默认关闭）**：任意路径自由配置，**基线 + 轮询**模式——启动只建基线不回灌历史图片，运行时每秒轮询，仅新增图片挂上；自动识别中文本地化截屏目录（`~/Pictures/屏幕截图`），支持中文路径/文件名
#### 注意！文件夹监听：由于 mac 的特性（截图后不会立刻保存，直到右下角图片消失），文件夹监听不能做到实时上绳。

### 绳子
- 麻绳质感曲线（投影/主体/暗部/高光/捻纹五层绘制），中部下垂，衣夹悬挂
- 挂图从**中心向两侧交替延伸**；数量过多时方块自动缩小（28~84pt），放不下回退横向滚动
- 正方形缩略图（中心裁剪，无视原比例）
- **悬停高亮**：强调色边框 + 轻微弹起 + 手型光标
- 鼠标离开 0.35s 自动收起；可设置**常驻屏幕**不收起
- **背景全透明**模式：只留绳子和截图本体

### 操作
| 动作 | 效果 |
|---|---|
| 单击图片 | 复制（屏幕居中 HUD 提示） |
| 双击图片 | 钉到桌面 |
| 右键图片 | 复制 / 钉在桌面 / 存储到… / 删除此图片 / 移除除此之外所有图片 / 删除绳子上所有图片 |
| 拖动绳子空白处 | 移动绳子位置（抓手光标，位置持久化） |
| 右键绳子空白处 | 截图放大 / 截图缩小 / 重置位置与大小 |
| 滚轮 / 触控板横滑 | 浏览绳子 |

### 桌面贴图
置顶小窗，任意位置按住拖动，滚轮以图片中心缩放，双击关闭，右键复制/关闭

### 持久化
- 截图自动落盘 `~/Library/Application Support/PicRopeForMac/captures/`，**重启恢复**
- 绳子位置、缩放、常驻、透明、监听路径等设置全部持久化
- 绳子上限 50 张（含磁盘文件同步淘汰）
- 删除操作同步删除磁盘文件

## 使用

```bash
./build.sh          # 构建 release 并打包 .app
open PicRopeForMac.app
```

或开发模式：`swift build && ./.build/debug/PicRopeForMac`

菜单栏图标：显示/隐藏绳子、设置…、清空绳子、退出。

设置项（点「确定」才生效）：剪贴板收集、文件夹监听与路径、绳子常驻、背景全透明、开机自启动（SMAppService，勾选即注册）。

## 分发

```bash
codesign --force --deep --sign - PicRopeForMac.app
ditto -c -k --keepParent PicRopeForMac.app PicRopeForMac.zip
```

无开发者账号时接收方需右键 → 打开（或 `xattr -dr com.apple.quarantine`）放行 Gatekeeper；正式分发建议 Developer ID 签名 + 公证或走 TestFlight。

## 与原版差异（有意为之）

| 原版 (Windows) | Mac 版 |
|---|---|
| 监听截图文件夹为主（Win+PrtScn） | **剪贴板为主**（Mac 用户大量使用第三方截图工具），文件夹监听为辅且路径自由配置 |
| .NET 4.8 WinForms 自绘 + WebView2 编辑器 | Swift + AppKit（编辑器暂未实现，规划中） |

## 规划中

图片编辑器（参考原版 `src/editor` 的 HTML/JS 资产，WKWebView 内嵌）、应用图标、多外观主题、应用内更新（Sparkle）

## 致谢

创意来自 [PicRope](https://github.com/Renly1994/PicRope)（其创意参考 Tendedeo），许可与来源声明见原项目 LICENSE / NOTICE。
