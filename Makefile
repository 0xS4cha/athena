PROJECT_NAME ?= athena
APP_NAME := $(shell grep -oP "name\s*=\s*'\K[^']+" build.lua)
LOVE_VERSION ?= 11.5
BUILD_TOOL_DIR ?= love-build
BUILD_TOOL ?= $(BUILD_TOOL_DIR)/AppRun
APPIMAGETOOL ?= appimagetool.AppImage
SERVER_NAME ?= athena_server
SERVER_DIR ?= server
DIST_DIR ?= dist
BUILD_DIR ?= build
VERSION := $(shell grep -oP "version\s*=\s*'\K[^']+" build.lua)
MAIN_LUA := $(shell find . -maxdepth 1 -name "main.lua" | head -n 1)
ifeq ($(MAIN_LUA),)
$(error "main.lua unknow")
endif

all: build

build: $(BUILD_TOOL)
	@mkdir -p $(DIST_DIR)
	@$(BUILD_TOOL) $(abspath $(MAIN_LUA))

$(BUILD_TOOL):
	@mkdir -p $(BUILD_TOOL_DIR)
	@wget -q -O $(BUILD_TOOL_DIR).zip "https://github.com/ellraiser/love-build/releases/download/v0.9/love-build-0.9-linux.zip"
	@unzip -q -o $(BUILD_TOOL_DIR).zip -d $(BUILD_TOOL_DIR)
	@rm -f $(BUILD_TOOL_DIR).zip
	@chmod -R u+rwX $(BUILD_TOOL_DIR)

$(APPIMAGETOOL):
	@wget -q -O $(APPIMAGETOOL) "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
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
	@cd $(DIST_DIR)/$(VERSION) && tar -czvf ../../$(PROJECT_NAME)-linux.tar.gz *

.PHONY: all build run server test clean fclean dist standalone standalone-server