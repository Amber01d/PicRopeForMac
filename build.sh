#!/bin/zsh
# 构建 PicRopeForMac.app 并打包发版 zip
# 发版时改 VERSION，产物：PicRopeForMac-$VERSION.zip
set -e
cd "$(dirname "$0")"

VERSION="PRFM.0.1"

echo "== swift build (release) =="
swift build -c release

APP="PicRopeForMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PicRopeForMac "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PicRopeForMac</string>
    <key>CFBundleIdentifier</key><string>com.picrope.mac</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# ad-hoc 签名（无开发者账号场景）
codesign --force --deep --sign - "$APP" 2>/dev/null || true

ZIP="PicRopeForMac-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "== done: $APP / $ZIP (v$VERSION) =="
echo "运行: open $APP   （退出: 菜单栏图标 → 退出 PicRope）"
