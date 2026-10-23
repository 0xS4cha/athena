PROJECT_NAME ?= athena
APP_NAME := $(shell sed -n "s/^ *name *= *'\([^']*\)'.*/\1/p" build.lua | head -n 1)
LOVE_VERSION ?= 11.5
LOVE_BUILD_VERSION ?= 1.0
BUILD_TOOL_DIR ?= love-build
UNAME := $(shell uname -s)
ifeq ($(UNAME),Darwin)
LOVE_BUILD_OS := macos
BUILD_TOOL ?= $(BUILD_TOOL_DIR)/love-build.app/Contents/MacOS/love
else
LOVE_BUILD_OS := linux
BUILD_TOOL ?= $(BUILD_TOOL_DIR)/AppRun
endif
APPIMAGETOOL ?= appimagetool.AppImage
SERVER_NAME ?= athena_server
SERVER_DIR ?= server
DIST_DIR ?= dist
BUILD_DIR ?= build
VERSION := $(shell sed -n "s/^ *version *= *'\([^']*\)'.*/\1/p" build.lua | head -n 1)
MAIN_LUA := $(shell find . -maxdepth 1 -name "main.lua" | head -n 1)
ifeq ($(MAIN_LUA),)
$(error "main.lua unknow")
endif

all: build

build: $(BUILD_TOOL)
	@mkdir -p $(DIST_DIR)
	@$(BUILD_TOOL) $(abspath $(MAIN_LUA))

build-windows build-macos build-linux: $(BUILD_TOOL)
	@mkdir -p $(DIST_DIR)
	@$(BUILD_TOOL) $(abspath $(MAIN_LUA)) $(@:build-%=%)

$(BUILD_TOOL):
	@mkdir -p $(BUILD_TOOL_DIR)
	@curl -sSL -o $(BUILD_TOOL_DIR).zip "https://github.com/ellraiser/love-build/releases/download/v$(LOVE_BUILD_VERSION)/love-build-$(LOVE_BUILD_VERSION)-$(LOVE_BUILD_OS).zip"
	@unzip -q -o $(BUILD_TOOL_DIR).zip -d $(BUILD_TOOL_DIR)
	@rm -f $(BUILD_TOOL_DIR).zip
	@chmod -R u+rwX $(BUILD_TOOL_DIR)

$(APPIMAGETOOL):
	@curl -sSL -o $(APPIMAGETOOL) "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
	@chmod +x $(APPIMAGETOOL)

standalone: fclean build $(APPIMAGETOOL)
	@rm -rf $(BUILD_DIR)/$(PROJECT_NAME).AppDir
	@mkdir -p $(BUILD_DIR)
	@unzip -q -o $(DIST_DIR)/$(VERSION)/$(APP_NAME)-linux.zip -d $(BUILD_DIR)/$(PROJECT_NAME).AppDir
	@chmod -R u+rwX $(BUILD_DIR)/$(PROJECT_NAME).AppDir
	
	@mkdir -p $(BUILD_DIR)/$(PROJECT_NAME).AppDir/lib
	@chmod +x $(BUILD_DIR)/$(PROJECT_NAME).AppDir/AppRun $(BUILD_DIR)/$(PROJECT_NAME).AppDir/bin/*
	@ARCH=x86_64 ./$(APPIMAGETOOL) $(BUILD_DIR)/$(PROJECT_NAME).AppDir ./$(PROJECT_NAME)
	@chmod +x ./$(PROJECT_NAME)
	@$(MAKE) --no-print-directory standalone-server

standalone-server: $(APPIMAGETOOL)
	@rm -rf $(BUILD_DIR)/$(SERVER_NAME) $(BUILD_DIR)/$(SERVER_NAME).AppDir
	@mkdir -p $(BUILD_DIR)/$(SERVER_NAME)/assets
	@cp -r $(SERVER_DIR)/. $(BUILD_DIR)/$(SERVER_NAME)/
	@cp -r src $(BUILD_DIR)/$(SERVER_NAME)/
	@cp -r libs $(BUILD_DIR)/$(SERVER_NAME)/
	@cp -r assets/maps $(BUILD_DIR)/$(SERVER_NAME)/assets/
	@cd $(BUILD_DIR)/$(SERVER_NAME) && zip -q -9 -r ../$(SERVER_NAME).love .
	@cp -r $(BUILD_DIR)/$(PROJECT_NAME).AppDir $(BUILD_DIR)/$(SERVER_NAME).AppDir
	@rm -f $(BUILD_DIR)/$(SERVER_NAME).AppDir/bin/$(APP_NAME)
	@head -c $$(( $$(stat -c %s $(BUILD_DIR)/$(PROJECT_NAME).AppDir/bin/$(APP_NAME)) - $$(stat -c %s $(DIST_DIR)/$(VERSION)/$(APP_NAME).love) )) \
		$(BUILD_DIR)/$(PROJECT_NAME).AppDir/bin/$(APP_NAME) > $(BUILD_DIR)/$(SERVER_NAME).AppDir/bin/$(SERVER_NAME)
	@cat $(BUILD_DIR)/$(SERVER_NAME).love >> $(BUILD_DIR)/$(SERVER_NAME).AppDir/bin/$(SERVER_NAME)
	@sed -i 's|bin/$(APP_NAME)"|bin/$(SERVER_NAME)"|' $(BUILD_DIR)/$(SERVER_NAME).AppDir/AppRun
	@sed -i -e 's|^Name=.*|Name=$(SERVER_NAME)|' -e 's|^Exec=.*|Exec=$(SERVER_NAME) %f|' -e 's|^Terminal=.*|Terminal=true|' $(BUILD_DIR)/$(SERVER_NAME).AppDir/love.desktop
	@chmod +x $(BUILD_DIR)/$(SERVER_NAME).AppDir/AppRun $(BUILD_DIR)/$(SERVER_NAME).AppDir/bin/*
	@ARCH=x86_64 ./$(APPIMAGETOOL) $(BUILD_DIR)/$(SERVER_NAME).AppDir ./$(SERVER_NAME)
	@chmod +x ./$(SERVER_NAME)

run:
	@love .

server:
	@love . --server

test:
	@love . --test

clean:
	@rm -rf $(DIST_DIR) $(BUILD_DIR) $(BUILD_TOOL_DIR)
	@rm -f $(APPIMAGETOOL)
	@find . -name "*.love" -type f -delete

fclean: clean
	@rm -f ./$(PROJECT_NAME) ./$(SERVER_NAME)

dist: build
	@ls -1 $(DIST_DIR)/$(VERSION)/$(APP_NAME)-*.zip

.PHONY: all build build-windows build-macos build-linux run server test clean fclean dist standalone standalone-server