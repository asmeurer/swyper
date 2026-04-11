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

# Code signing: CODESIGN_IDENTITY signs with an installed non-ad-hoc identity.
# For development builds without CODESIGN_IDENTITY, rcodesign with a self-signed
# certificate produces a stable designated requirement, falling back to ad-hoc.
CODESIGN_IDENTITY ?=
CODESIGN_IDENTITY_TRIMMED := $(strip $(CODESIGN_IDENTITY))
RCODESIGN := $(shell command -v rcodesign 2>/dev/null)
RCODESIGN_CERT := $(HOME)/.config/swyper/swyper-rcodesign.crt
RCODESIGN_KEY := $(HOME)/.config/swyper/swyper-rcodesign.key

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
ifneq ($(CODESIGN_IDENTITY_TRIMMED),)
ifeq ($(CODESIGN_IDENTITY_TRIMMED),-)
	@codesign --force --sign - --entitlements Swyper.entitlements "$(APP_BUNDLE)/Contents/MacOS/Swyper"
	@echo "Built $(APP_BUNDLE) (v$(DISPLAY_VERSION)) [ad-hoc signed]"
else
	@codesign --force --deep --sign "$(CODESIGN_IDENTITY)" --options runtime "$(APP_BUNDLE)/Contents/Frameworks/Sparkle.framework"
	@codesign --force --sign "$(CODESIGN_IDENTITY)" --options runtime --entitlements Swyper.entitlements "$(APP_BUNDLE)"
	@codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE) (v$(DISPLAY_VERSION)) [signed with codesign: $(CODESIGN_IDENTITY)]"
endif
else ifneq ($(and $(RCODESIGN),$(wildcard $(RCODESIGN_CERT)),$(wildcard $(RCODESIGN_KEY))),)
	@rcodesign sign --pem-source "$(RCODESIGN_KEY)" --pem-source "$(RCODESIGN_CERT)" \
		--code-signature-flags runtime --entitlements-xml-path Swyper.entitlements "$(APP_BUNDLE)" >/dev/null
	@echo "Built $(APP_BUNDLE) (v$(DISPLAY_VERSION)) [signed with rcodesign]"
else
	@codesign --force --sign - --entitlements Swyper.entitlements "$(APP_BUNDLE)/Contents/MacOS/Swyper"
	@echo "Built $(APP_BUNDLE) (v$(DISPLAY_VERSION)) [ad-hoc signed]"
endif

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
