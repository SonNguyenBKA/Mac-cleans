PROJECT = MacCleaner.xcodeproj
XCB = xcodebuild -project $(PROJECT) -scheme MacCleaner -derivedDataPath build -destination 'platform=macOS,arch=arm64'
APP = build/Build/Products/$(CONFIG)/MacCleaner.app
CONFIG ?= Debug
# Ký bằng chứng chỉ cố định để macOS nhớ quyền (Full Disk Access…) qua các lần build.
# Ký ad-hoc thì mỗi bản build là một "app mới" và bị hỏi quyền lại.
SIGN_ID ?= 116C280C9B0323FEED9DE844FAB103994AB3E692

.PHONY: gen build test run install dmg clean

gen:
	xcodegen generate --quiet

build: gen
	$(XCB) -quiet -configuration $(CONFIG) build
	codesign --force --sign $(SIGN_ID) --identifier com.local.MacCleaner.FanHelper $(APP)/Contents/MacOS/MacCleanerFanHelper
	codesign --force --sign $(SIGN_ID) $(APP)/Contents/Frameworks/MacCleanerCore.framework
	codesign --force --sign $(SIGN_ID) $(APP)
	@spctl -a -t exec $(APP) 2>&1 | grep -q REVOKED && { echo "Chứng chỉ $(SIGN_ID) đã bị thu hồi, app sẽ không mở được"; exit 1; } || true

test: gen
	set -o pipefail; $(XCB) test 2>&1 | grep -E "error:|failed|Executed|TEST (SUCCEEDED|FAILED)"

run: build
	open $(APP)

install:
	$(MAKE) build CONFIG=Release
	rm -rf /Applications/MacCleaner.app
	cp -R build/Build/Products/Release/MacCleaner.app /Applications/

# File cài đặt: kéo MacCleaner.app vào Applications. Ra build/MacCleaner.dmg.
dmg:
	$(MAKE) build CONFIG=Release
	rm -rf build/dmg build/MacCleaner.dmg
	mkdir -p build/dmg
	cp -R build/Build/Products/Release/MacCleaner.app build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "Mac Cleaner" -srcfolder build/dmg -format UDZO -ov build/MacCleaner.dmg
	codesign --force --sign $(SIGN_ID) build/MacCleaner.dmg

clean:
	rm -rf build $(PROJECT)
