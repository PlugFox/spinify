.PHONY: format get test publish deploy centrifugo-up centrifugo-down coverage analyze check pana generate

format:
	@echo "Formatting the code"
	@dart format -l 80 --fix .
	@dart fix --apply .

get:
	@dart pub get

test: get
	@dart test --debug --coverage=.coverage --platform chrome,vm

publish:
	@yes | dart pub publish

deploy: publish

centrifugo-up:
	@docker run -d --rm --ulimit nofile=65536:65536 -p 8000:8000 --name centrifugo centrifugo/centrifugo:latest centrifugo --client_insecure --admin --admin_insecure --log_level=debug

centrifugo-down:
	@docker stop centrifugo

coverage: get
	@dart test --concurrency=6 --platform vm --coverage=coverage test/
	@dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.packages --report-on=lib
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
	@protoc --proto_path=lib/src/transport/protobuf --dart_out=lib/src/transport/protobuf lib/src/transport/protobuf/client.proto
	@dart run build_runner build --delete-conflicting-outputs
	@dart format -l 80 lib/src/model/pubspec.yaml.g.dart lib/src/transport/protobuf/