import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpTab extends StatelessWidget {
  const HelpTab({
    super.key, // ignore: unused_element
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _HelpStep(1, [
            const TextSpan(text: 'Create a file named "'),
            TextSpan(
              text: 'docker-compose.yml',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const TextSpan(text: '" in the project root directory.'),
          ]),
          const SizedBox(height: 16),
          const _HelpStep(2, [
            TextSpan(text: 'Add the following content: '),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  fit: StackFit.loose,
                  alignment: Alignment.topLeft,
                  children: <Widget>[
                    const Text(_helpComposeContent),
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          await Clipboard.setData(
                              const ClipboardData(text: _helpComposeContent));
                          messenger
                            ?..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HelpStep(3, [
            const TextSpan(text: 'Run "'),
            TextSpan(
              text: 'docker-compose up',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const TextSpan(text: '" to start the services.'),
          ]),
          const Divider(height: 16 * 2),
          const _HelpStep(4, [
            TextSpan(text: 'Select the library to benchmark.'),
          ]),
          const SizedBox(height: 16),
          const _HelpStep(5, [
            TextSpan(text: 'Enter the endpoint URL.'),
          ]),
          const SizedBox(height: 16),
          const _HelpStep(6, [
            TextSpan(text: 'Select the payload size.'),
          ]),
          const SizedBox(height: 16),
          const _HelpStep(7, [
            TextSpan(text: 'Select the message count.'),
          ]),
          const SizedBox(height: 16),
          const _HelpStep(8, [
            TextSpan(text: 'Press the "'),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.play_arrow,
                size: 18,
                color: Colors.green,
              ),
            ),
            TextSpan(text: '" button.'),
          ]),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep(
    this.step,
    this.description, {
    super.key, // ignore: unused_element
  });

  final int step;

  final List<InlineSpan> description;

  static const String _$nbsp = '\u00A0';
  static String _stepToEmoji(int step) => switch (step) {
        0 => '0️⃣',
        1 => '1️⃣',
        2 => '2️⃣',
        3 => '3️⃣',
        4 => '4️⃣',
        5 => '5️⃣',
        6 => '6️⃣',
        7 => '7️⃣',
        8 => '8️⃣',
        9 => '9️⃣',
        10 => '🔟',
        _ => step.toString(),
      };

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '${_stepToEmoji(step)}${_$nbsp * 2}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ...description,
          ],
        ),
      );
}

const String _helpComposeContent = '''
version: "3.9"

services:
  centrifugo-benchmark:
    container_name: centrifugo-benchmark
    image: centrifugo/centrifugo:v5
    restart: unless-stopped
    command: centrifugo
    tty: true
    ports:
      - 8000:8000
    environment:
      - "CENTRIFUGO_ADMIN=true"
      - "CENTRIFUGO_TOKEN_HMAC_SECRET_KEY=80e88856-fe08-4a01-b9fc-73d1d03c2eee"
      - "CENTRIFUGO_ADMIN_PASSWORD=6cec4cc2-960d-4e4a-b650-0cbd4bbf0530"
      - "CENTRIFUGO_ADMIN_SECRET=70957aac-555b-4bce-b9b8-53ada3a8029e"
      - "CENTRIFUGO_API_KEY=8aba9113-d67a-41c6-818a-27aaaaeb64e7"
      - "CENTRIFUGO_ALLOWED_ORIGINS=*"
      - "CENTRIFUGO_HEALTH=true"
      - "CENTRIFUGO_HISTORY_SIZE=10"
      - "CENTRIFUGO_HISTORY_TTL=300s"
      - "CENTRIFUGO_FORCE_RECOVERY=true"
      - "CENTRIFUGO_ALLOW_PUBLISH_FOR_CLIENT=true"
      - "CENTRIFUGO_ALLOW_SUBSCRIBE_FOR_CLIENT=true"
      - "CENTRIFUGO_ALLOW_SUBSCRIBE_FOR_ANONYMOUS=true"
      - "CENTRIFUGO_ALLOW_PUBLISH_FOR_SUBSCRIBER=true"
      - "CENTRIFUGO_ALLOW_PUBLISH_FOR_ANONYMOUS=true"
      - "CENTRIFUGO_ALLOW_USER_LIMITED_CHANNELS=true"
      - "CENTRIFUGO_LOG_LEVEL=debug"
    healthcheck:
      test: ["CMD", "sh", "-c", "wget -nv -O - http://localhost:8000/health"]
      interval: 3s
      timeout: 3s
      retries: 3
    ulimits:
      nofile:
        soft: 65535
        hard: 65535''';
