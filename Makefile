.PHONY: format get outdated test publish deploy echo-up echo-down coverage analyze check pana generate

ifeq ($(OS),Windows_NT)
    RM = del /Q
    MKDIR = mkdir
    PWD = $(shell $(PWD))
else
    RM = rm -f
    MKDIR = mkdir -p
    PWD = pwd
endif

format:
	@echo "Formatting the code"
	@dart format -l 80 --fix .
	@dart fix --apply .

get:
	@dart pub get

outdated:
	@dart pub outdated --show-all --dev-dependencies --dependency-overrides --transitive --no-prereleases

test: get
	@dart test --debug --coverage=coverage --platform chrome,vm test/unit_test.dart

publish: generate
	@yes | dart pub publish

deploy: publish

echo-up:
	@dart run tool/echo_up.dart

echo-down:
	@dart run tool/echo_down.dart

coverage: get
	@dart test --concurrency=6 --platform vm --coverage=coverage test/
	@dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
#	@mv coverage/lcov.info coverage/lcov.base.info
#	@lcov -r coverage/lcov.base.info -o coverage/lcov.base.info "lib/**.freezed.dart" "lib/**.g.dart"
#	@mv coverage/lcov.base.info coverage/lcov.info
	@lcov --list coverage/lcov.info
	@genhtml -o coverage coverage/lcov.info

analyze: get format
	@echo "Analyze the code"
	@dart analyze --fatal-infos --fatal-warnings

check: analyze
	@dart pub publish --dry-run
	@dart pub global activate pana
	@pana --json --no-warning --line-length 80 > log.pana.json

pana: check

generate: get
	@dart pub global activate protoc_plugin
	@protoc --proto_path=lib/src/protobuf --dart_out=lib/src/protobuf lib/src/protobuf/client.proto
	@dart run build_runner build --delete-conflicting-outputs
	@dart format -l 80 lib/src/model/pubspec.yaml.g.dart lib/src/protobuf/

gen: generate

codegen: generate