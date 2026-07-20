PROJECT_NAME ?= $(shell grep -oP "name\s*=\s*'\K[^']+" build.lua)
LOVE_VERSION ?= $(shell grep -oP "love\s*=\s*'\K[^']+" build.lua)
BUILD_TOOL_DIR ?= love-build
BUILD_TOOL ?= $(BUILD_TOOL_DIR)/AppRun
APPIMAGETOOL ?= appimagetool.AppImage
DIST_DIR ?= $(shell grep -oP "output\s*=\s*'\K[^']+" build.lua)
BUILD_DIR ?= build
VERSION := $(shell grep -oP "version\s*=\s*'\K[^']+" build.lua)
MAIN_LUA := $(shell find . -maxdepth 1 -name "main.lua" | head -n 1)
ifeq ($(MAIN_LUA),)
$(error "main.lua unknow")
endif

all: run

run:
	@love .

clean:
	@rm -rf $(DIST_DIR) $(BUILD_DIR) $(BUILD_TOOL_DIR)
	@rm -f $(APPIMAGETOOL)
	@find . -name "*.love" -type f -delete

fclean: clean
	@rm -f ./$(PROJECT_NAME)

dist: build
	@cd $(DIST_DIR)/$(VERSION) && tar -czvf ../../$(PROJECT_NAME)-linux.tar.gz *

.PHONY: all build run clean fclean dist standalone