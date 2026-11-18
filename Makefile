.PHONY: test project

test:
	cd Packages/PagewormCore && swift test

project:
	python3 scripts/generate_xcodeproj.py
