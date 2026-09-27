# Uses the full Xcode install even if xcode-select points at the Command Line Tools.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
DERIVED = build/DerivedData
APP = $(DERIVED)/Build/Products/Debug/Advisor OS.app

.PHONY: cert project build run test icon dmg clean

cert:               ## Create the local signing identity once (keeps macOS permissions across rebuilds)
	./scripts/make-signing-cert.sh

project: cert       ## Regenerate AdvisorOS.xcodeproj from project.yml
	xcodegen generate

build: project
	xcodebuild -project AdvisorOS.xcodeproj -scheme AdvisorOS -configuration Debug -derivedDataPath $(DERIVED) build -quiet

run: build
	open "$(APP)"

test: project
	xcodebuild -project AdvisorOS.xcodeproj -scheme AdvisorOS -derivedDataPath $(DERIVED) test -quiet

icon:
	swift scripts/make-icon.swift

dmg: cert          ## Release build packaged as dist/AdvisorOS-<version>.dmg (not notarized)
	./scripts/make-dmg.sh

clean:
	rm -rf build dist
