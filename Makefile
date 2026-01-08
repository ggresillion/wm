APP_NAME = macwm
BIN_DIR = $(HOME)/.local/bin
PLIST_SRC = macwm.plist
PLIST_DST = ~/Library/LaunchAgents/com.ggresillion.macwm.plist

all: build

build:
	go build -o $(APP_NAME) main.go

install: build
	mkdir -p $(BIN_DIR)
	install -m 755 macwm $(BIN_DIR)/
	mkdir -p ~/Library/LaunchAgents
	cp macwm.plist $(PLIST_DST)
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	launchctl load $(PLIST_DST)
	echo "Installed $(BIN_DIR)/macwm and LaunchAgent"

uninstall:
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	rm -f $(BIN_DIR)/$(APP_NAME)
	rm -f $(PLIST_DST)
	echo "Uninstalled $(APP_NAME)"

.PHONY: all build install uninstall
