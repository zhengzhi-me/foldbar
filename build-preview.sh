#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
preview_build_dir="${TMPDIR:-/private/tmp}/hidden-bar-macos27-preview-build"
xcodebuild -project 'Hidden Bar.xcodeproj' -scheme 'Hidden Bar' \
  -configuration Release-Direct -derivedDataPath "$preview_build_dir" \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  PRODUCT_NAME=FoldBar PRODUCT_BUNDLE_IDENTIFIER=me.zhengzhi.foldbar \
  ASSETCATALOG_COMPILER_APPICON_NAME= \
  MARKETING_VERSION=0.1.2 CURRENT_PROJECT_VERSION=4 build
preview_app="$preview_build_dir/Build/Products/Release-Direct/FoldBar.app"
icon_work="$(mktemp -d "${TMPDIR:-/private/tmp}/foldbar-icon.XXXXXX")"
xcrun actool hidden/Assets.xcassets FoldBarIcon.icon \
  --compile "$preview_app/Contents/Resources" \
  --output-partial-info-plist "$icon_work/IconInfo.plist" \
  --app-icon FoldBarIcon --platform macosx --target-device mac \
  --minimum-deployment-target 13.0 --output-format human-readable-text \
  --errors --warnings
for key in CFBundleIconFile CFBundleIconName; do
  value="$(plutil -extract "$key" raw "$icon_work/IconInfo.plist")"
  plutil -replace "$key" -string "$value" "$preview_app/Contents/Info.plist"
done
codesign --force --sign "${FOLDBAR_SIGN_IDENTITY:--}" --identifier me.zhengzhi.foldbar "$preview_app"
codesign --verify --deep --strict "$preview_app"
ditto -c -k --sequesterRsrc --keepParent "$preview_app" './FoldBar-0.1.2-preview.zip'
print 'Built FoldBar-0.1.2-preview.zip'
