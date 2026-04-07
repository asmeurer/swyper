.PHONY: build bundle clean run install

BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/Swyper.app
BINARY = .build/release/Swyper

build:
	swift build -c release

bundle: build
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp $(BINARY) "$(APP_BUNDLE)/Contents/MacOS/Swyper"
	@cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --sign - --entitlements Swyper.entitlements "$(APP_BUNDLE)/Contents/MacOS/Swyper"
	@echo "Built $(APP_BUNDLE)"

run: bundle
	@open "$(APP_BUNDLE)"

install: bundle
	@cp -R "$(APP_BUNDLE)" /Applications/Swyper.app
	@echo "Installed to /Applications/Swyper.app"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)
