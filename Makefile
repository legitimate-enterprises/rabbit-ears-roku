# Node comes from the PATH; with nvm, select an LTS first.
.DEFAULT_GOAL := help
.PHONY: help deps generate build run release deploy spec test test-unit style lint format clean

BRS := source/*.brs components/*.brs components/*/*.brs tests/*.brs

help: ## Print this target list
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-16s %s\n", $$1, $$2}'

deps: ## Install npm packages from the lockfile
	npm ci

generate: ## Draw the icons, splash screens and focus images into build/images
	node scripts/images.mjs build/images

# bsc only validates: its own package rewrites the XML and adds its
# runtime, so the zip holds the sources as written.
build: generate ## Validate with bsc and zip the app into build/rabbit-ears.zip
	npx bsc --project bsconfig.json --create-package=false --copy-to-staging=false
	rm -f build/rabbit-ears.zip
	zip -qr build/rabbit-ears.zip manifest source components -x '*.DS_Store'
	cd build && zip -qr rabbit-ears.zip images

# Developer mode only; the store build is uploaded by hand.
run: ## Sideload the package to ROKU_HOST with ROKU_PASSWORD
	@[ -n "$$ROKU_HOST" ] && [ -n "$$ROKU_PASSWORD" ] || \
		{ echo "usage: ROKU_HOST=<device address> ROKU_PASSWORD=<developer password> make run" >&2; exit 64; }
	$(MAKE) --no-print-directory build
	curl -sS --fail --digest -u "rokudev:$$ROKU_PASSWORD" -F mysubmit=Install \
		-F "archive=@build/rabbit-ears.zip" "http://$$ROKU_HOST/plugin_install" >/dev/null

# The file's info.version is the server release this app is built against.
spec: ## Replace openapi.yaml with the one from server release VERSION (make spec VERSION=0.20.0)
	@[ -n "$(VERSION)" ] || { echo "usage: make spec VERSION=<server version>" >&2; exit 64; }
	curl --fail --silent --show-error --location --output openapi.yaml.new \
		"https://raw.githubusercontent.com/legitimate-enterprises/rabbit-ears/v$(VERSION)/server/api/openapi.yaml"
	mv openapi.yaml.new openapi.yaml

# There is no local publish path.
deploy: ## Tag origin/main v<version> once CI is green there, and push the tag
	scripts/cut-release.sh --yes

# CI only, for a v<version> tag. Needs ROKU_HOST, ROKU_PASSWORD,
# ROKU_SIGNING_PASSWORD and GH_TOKEN; the host is a Roku in developer mode
# that holds the app's signing key.
release: ## Sign the package on the Roku at ROKU_HOST and attach it to TAG's GitHub release
	scripts/release.sh $(TAG)

test: style lint build test-unit ## Every gate CI enforces

test-unit: ## BrightScript unit tests under brs, the API client against the spec, the release script against a fake Roku
	node --test tests/*.test.mjs

style: ## bsfmt in checking mode
	npx bsfmt --check $(BRS)

format: ## bsfmt in place
	npx bsfmt --write $(BRS)

lint: ## bslint over the project
	npx bslint --project bsconfig.json

clean: ## Remove build products and node_modules
	rm -rf build node_modules
