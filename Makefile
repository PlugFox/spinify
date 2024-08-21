ifeq ($(OS),Windows_NT)
	SHELL = cmd
    RM = del /Q
    MKDIR = mkdir
    PWD = $(shell $(PWD))
else
	SHELL = /bin/bash -e -o pipefail
    RM = rm -f
    MKDIR = mkdir -p
    PWD = pwd
endif

.DEFAULT_GOAL := all
.PHONY: all
all: ## build pipeline
all: format check test

.PHONY: precommit
precommit: ## validate the branch before commit
precommit: all

.PHONY: help
help:
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: format
format: ## Format the code
	@dart format -l 80 --fix lib/ test/ example/
	@dart fix --apply .

.PHONY: get
get: ## Get the dependencies
	@dart pub get

.PHONY: outdated
outdated: get ## Check for outdated dependencies
	@dart pub outdated --show-all --dev-dependencies --dependency-overrides --transitive --no-prereleases

.PHONY: test
test: get ## Run the tests
	@dart test --debug --coverage=coverage --platform vm,chrome test/unit_test.dart

.PHONY: publish-check
publish-check: ## Check the package before publishing
	@dart pub publish --dry-run

.PHONY: deploy-check
deploy-check: publish-check

.PHONY: publish
publish: generate ## Publish the package
	@yes | dart pub publish

.PHONY: deploy
deploy: publish

.PHONY: echo-up
echo-up: ## Start the echo server
	@dart run tool/echo_up.dart

.PHONY: echo-down
echo-down: ## Stop the echo server
	@dart run tool/echo_down.dart

.PHONY: coverage
coverage: get ## Generate the coverage report
	@dart pub global activate coverage
	@dart pub global run coverage:test_with_coverage -fb -o coverage -- \
		--platform vm --compiler=kernel --coverage=coverage \
		--reporter=expanded --file-reporter=json:coverage/tests.json \
		--timeout=10m --concurrency=12 --color \
			test/unit_test.dart test/smoke_test.dart
#	@dart test --concurrency=6 --platform vm --coverage=coverage test/
#	@dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
	@mv coverage/lcov.info coverage/lcov.base.info
	@lcov -r coverage/lcov.base.info -o coverage/lcov.base.info "lib/src/protobuf/client.*.dart" "lib/**/*.g.dart"
	@mv coverage/lcov.base.info coverage/lcov.info
	@lcov --list coverage/lcov.info
	@genhtml -o coverage coverage/lcov.info

.PHONY: analyze
analyze: get ## Analyze the code
	@dart format --set-exit-if-changed -l 80 -o none lib/ test/ example/
	@dart analyze --fatal-infos --fatal-warnings lib/ test/ example/

.PHONY: check
check: analyze publish-check ## Check the code
	@dart pub global activate pana
	@pana --json --no-warning --line-length 80 > log.pana.json

.PHONY: pana
pana: check

.PHONY: generate
generate: get ## Generate the code
	@dart pub global activate protoc_plugin
	@protoc --proto_path=lib/src/protobuf --dart_out=lib/src/protobuf lib/src/protobuf/client.proto
	@dart run build_runner build --delete-conflicting-outputs
	@dart format -l 80 lib/src/model/pubspec.yaml.g.dart lib/src/protobuf/ test/

.PHONY: gen
gen: generate

.PHONY: codegen
codegen: generate

.PHONY: diff
diff: ## git diff
	$(call print-target)
	@git diff --exit-code
	@RES=$$(git status --porcelain) ; if [ -n "$$RES" ]; then echo $$RES && exit 1 ; fi
