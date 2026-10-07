.PHONY: check project syntax test
project:
	python3 scripts/generate_xcode_project.py
check: project
	git diff --exit-code -- ios/TinkerCompanion.xcodeproj
	python3 -m unittest discover -s scripts/tests -v
syntax:
	python3 scripts/check_swift_syntax.py
test:
	xcodebuild -project ios/TinkerCompanion.xcodeproj -scheme TinkerCompanion -destination 'platform=iOS Simulator,name=$(PHONE)' CODE_SIGNING_ALLOWED=NO test
