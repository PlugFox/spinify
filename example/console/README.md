# Example console chat app

## Getting started with Centrifugo

Before running this example make sure you created `chat` namespace in Centrifugo configuration and allowed publishing into channel.

1. Call `centrifugo genconfig` to create a basic `config.json` at the first time.

2. Update the `config.json` file with tokens and namespaces, e.g.:

```json
{
  "token_hmac_secret_key": "<TOKEN HMAC SECRET KEY>",
  "admin_password": "<ADMIN PASSWORD>",
  "admin_secret": "<ADMIN SECRET>",
  "api_key": "<API KEY>",
  "allowed_origins": ["http://localhost:8000"],
  "namespaces": [
    {
      "name": "chat",
      "join_leave": true,
      "presence": true,
      "allow_publish_for_subscriber": true,
      "allow_subscribe_for_client": true
    }
  ]
}
```

3. When you use your own configuration, please re-generate the tokens registered in `example.dart`:

- Use `centrifugo gentoken --user dart` to generate the user's JWT token.
- Use `centrifugo gensubtoken --user dart --channel chat:index` to generate the user's subscription JWT token.

4. Run Centrifugo with the admin option, to later send messages to all subscribers:

```bash
centrifugo --admin
```

For testing purposes only, you can also run Centrifugo in insecure client mode, so that the validity of JWT tokens
are not checked:

```bash
centrifugo --client_insecure --admin
```

5. Now check the IP address if your system with `ipconfig` on Windows and `ip adds` on Unix-like systems and change the `serverAddr` variable in `example.dart` accordingly.

6. When the configuration is correct, you can launch the console app with `dart example.dart`.

7. When you have started centrifugo with the `--admin` option, you can also open `http://localhost:8000/#/actions` to send a message to your console app with the
   following settings:

- Method: Publish
- Channel: `chat:index`
- Data: `{"message": "hello world", "username": "admin"}`

Congratulations, you have a running centrifugo system and a Flutter console app that connects to it!

## Centrifugo with Docker

### Configurate Centrifugo

First, you need to create a config file for Centrifugo. You can do this with Docker:

1. Generate config file:

Bash:

```bash
docker run -it --rm --volume ${PWD}:/centrifugo \
    --name centrifugo centrifugo/centrifugo:latest centrifugo genconfig
```

PowerShell:

```powershell
docker run -it --rm --volume ${PWD}:/centrifugo `
    --name centrifugo centrifugo/centrifugo:latest centrifugo genconfig
```

2. Generate user token
   with `centrifugo gentoken --user dart` to generate the user's JWT token.
   `centrifugo gensubtoken --user dart --channel chat:index` to generate the user's subscription JWT token.

Bash:

```bash
docker run -it --rm --volume ${PWD}/config.json:/centrifugo/config.json:ro \
    --name centrifugo-cli centrifugo/centrifugo:latest \
    centrifugo gentoken --user dart
```

PowerShell:

```powershell
docker run -it --rm --volume ${PWD}/config.json:/centrifugo/config.json:ro `
    --name centrifugo-cli centrifugo/centrifugo:latest `
    centrifugo gentoken --user dart
```

### Run Centrifugo

You can also run the example with Docker. First, build the image:

Bash:

```bash
docker run -d -it --rm --ulimit nofile=65536:65536 -p 8000:8000/tcp \
    --volume ${PWD}/config.json:/centrifugo/config.json:ro \
    --name centrifugo centrifugo/centrifugo:latest centrifugo \
    --client_insecure --admin --admin_insecure --log_level=debug
```

PowerShell:

```powershell
docker run -d -it --rm --ulimit nofile=65536:65536 -p 8000:8000/tcp `
    --volume ${PWD}/config.json:/centrifugo/config.json:ro `
    --name centrifugo centrifugo/centrifugo:latest centrifugo `
    --client_insecure --admin --admin_insecure --log_level=debug
```

### Stop Centrifugo

Bash & PowerShell:

```bash
docker stop centrifugo
```
