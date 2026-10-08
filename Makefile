APP := GenMonBar.app

.PHONY: build run app-bundle clean

build:
	swift build -c release

run:
	swift run

app-bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/GenMonBar $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign - $(APP)
	@echo "Built $(APP) — open with: open $(APP)"

clean:
	swift package clean
	rm -rf $(APP)
