# Uses the full Xcode install even if xcode-select points at the Command Line Tools.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
DERIVED = build/DerivedData
APP = $(DERIVED)/Build/Products/Debug/Advisor OS.app

.PHONY: project build run test icon clean

project:            ## Regenerate AdvisorOS.xcodeproj from project.yml
	xcodegen generate

build: project
	xcodebuild -project AdvisorOS.xcodeproj -scheme AdvisorOS -configuration Debug -derivedDataPath $(DERIVED) build -quiet

run: build
	open "$(APP)"

test: project
	xcodebuild -project AdvisorOS.xcodeproj -scheme AdvisorOS -derivedDataPath $(DERIVED) test -quiet

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf build
