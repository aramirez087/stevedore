SCHEME      := Stevedore
DESTINATION := platform=macOS,arch=arm64
DERIVED     := .build/DerivedData

.PHONY: format-check lint build test app ci

# NOTE: paths MUST precede --lint (swiftformat 0.59 arg-parser quirk)
format-check:
	swiftformat Sources Tests App Package.swift --lint

lint:
	swiftlint --strict

build:
	swift build -Xswiftc -warnings-as-errors

test:
	swift test --parallel

app:
	xcodebuild -scheme $(SCHEME) \
	           -destination '$(DESTINATION)' \
	           -derivedDataPath $(DERIVED) \
	           clean build \
	           CODE_SIGNING_ALLOWED=NO

ci: format-check lint build test app
