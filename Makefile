.PHONY: build bundle clean run install lint icon

BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/Swyper.app
BINARY = .build/release/Swyper
SPARKLE_FRAMEWORK = .build/release/Sparkle.framework
APP_ICON_SVG = Resources/AppIcon.svg
APP_ICON_FALLBACK = Resources/AppIcon.icns
APP_ICON = $(BUILD_DIR)/AppIcon.icns
VERSION := $(shell cat VERSION)
DISPLAY_VERSION := $(VERSION)
BUNDLE_SHORT_VERSION := $(VERSION)
BUNDLE_VERSION := $(VERSION)
ifndef RELEASE
  DISPLAY_VERSION := $(VERSION)-dev.$(shell git rev-parse --short HEAD)
endif

# Code signing: Swyper only supports ad-hoc signing for local and release builds.

build:
	swift build -c release

$(APP_ICON): $(APP_ICON_SVG) $(APP_ICON_FALLBACK) scripts/generate-icon.sh
	@if command -v rsvg-convert >/dev/null 2>&1; then \
		./scripts/generate-icon.sh "$(APP_ICON_SVG)" "$@"; \
	else \
		mkdir -p "$(dir $@)"; \
		cp "$(APP_ICON_FALLBACK)" "$@"; \
		echo "Using committed icon fallback $(APP_ICON_FALLBACK); install librsvg to regenerate from $(APP_ICON_SVG)."; \
	fi

icon: $(APP_ICON)

bundle: build $(APP_ICON)
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@mkdir -p "$(APP_BUNDLE)/Contents/Frameworks"
	@cp $(BINARY) "$(APP_BUNDLE)/Contents/MacOS/Swyper"
	@cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@plutil -replace CFBundleShortVersionString -string "$(BUNDLE_SHORT_VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	@plutil -replace CFBundleVersion -string "$(BUNDLE_VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	@plutil -replace SwyperDisplayVersion -string "$(DISPLAY_VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	@cp "$(APP_ICON)" "$(APP_BUNDLE)/Contents/Resources/"
	@cp -RP "$(SPARKLE_FRAMEWORK)" "$(APP_BUNDLE)/Contents/Frameworks/"
	@install_name_tool -add_rpath @executable_path/../Frameworks "$(APP_BUNDLE)/Contents/MacOS/Swyper" 2>/dev/null || true
	@codesign --force --deep --sign - "$(APP_BUNDLE)/Contents/Frameworks/Sparkle.framework"
	@codesign --force --sign - --entitlements Swyper.entitlements "$(APP_BUNDLE)"
	@codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)/Contents/Frameworks/Sparkle.framework"
	@codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE) (v$(DISPLAY_VERSION)) [ad-hoc signed]"

run: bundle
	@open "$(APP_BUNDLE)"

install: bundle
	@cp -R "$(APP_BUNDLE)" /Applications/Swyper.app
	@echo "Installed to /Applications/Swyper.app"

lint:
	swiftlint

clean:
	swift package clean
	rm -rf $(BUILD_DIR)
