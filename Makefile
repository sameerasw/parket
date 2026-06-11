APP_NAME = Workspacer
INSTALL_DIR = /Applications/$(APP_NAME).app
BUILD_DIR = .build/derived_data/Build/Products/Release
CODESIGN_IDENTITY ?= -

.PHONY: build test install clean dist

build:
	xcodebuild -project Workspacer.xcodeproj -scheme Workspacer -configuration Release -derivedDataPath .build/derived_data build

install: build
	rm -rf $(INSTALL_DIR)
	cp -R $(BUILD_DIR)/$(APP_NAME).app $(INSTALL_DIR)
	codesign --force --options runtime --sign "$(CODESIGN_IDENTITY)" $(INSTALL_DIR)
	@echo "installed/updated $(INSTALL_DIR)"

dist: build
	rm -rf $(APP_NAME).app
	cp -R $(BUILD_DIR)/$(APP_NAME).app .
	codesign --force --options runtime --sign "$(CODESIGN_IDENTITY)" $(APP_NAME).app
	zip -r $(APP_NAME).zip $(APP_NAME).app
	@shasum -a 256 $(APP_NAME).zip

clean:
	rm -rf .build $(APP_NAME).zip $(APP_NAME).app


