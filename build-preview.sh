#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
preview_build_dir="${TMPDIR:-/private/tmp}/hidden-bar-macos27-preview-build"
xcodebuild -project 'Hidden Bar.xcodeproj' -scheme 'Hidden Bar' \
  -configuration Release-Direct -derivedDataPath "$preview_build_dir" \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  PRODUCT_NAME=FoldBar PRODUCT_BUNDLE_IDENTIFIER=me.zhengzhi.foldbar \
  MARKETING_VERSION=0.1.0 CURRENT_PROJECT_VERSION=2 build
preview_app="$preview_build_dir/Build/Products/Release-Direct/FoldBar.app"
codesign --force --sign "${FOLDBAR_SIGN_IDENTITY:--}" --identifier me.zhengzhi.foldbar "$preview_app"
codesign --verify --deep --strict "$preview_app"
ditto -c -k --sequesterRsrc --keepParent "$preview_app" './FoldBar-0.1.0-icon-preview.zip'
print 'Built FoldBar-0.1.0-icon-preview.zip'
