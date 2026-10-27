#!/bin/zsh
# 构建 PicRopeForMac.app
set -e
cd "$(dirname "$0")"

echo "== swift build (release) =="
swift build -c release

APP="PicRopeForMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PicRopeForMac "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PicRopeForMac</string>
    <key>CFBundleIdentifier</key><string>com.picrope.mac</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

echo "== done: $APP =="
echo "运行: open $APP   （退出: 菜单栏图标 → 退出 PicRope）"
