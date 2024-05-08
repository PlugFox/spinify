package main

import (
	"context"
	log "log"
	"os"
	"os/signal"
	"time"

	"io"
	"net/http"
	"syscall"

	"github.com/centrifugal/centrifuge"
)

// waitExitSignal waits for the SIGINT or SIGTERM signal to shutdown the centrifuge node.
// It creates a channel to receive signals and a channel to indicate when the shutdown is complete.
// Then it notifies the channel for SIGINT and SIGTERM signals and starts a goroutine to wait for the signal.
// Once the signal is received, it shuts down the centrifuge node and indicates that the shutdown is complete.
func waitExitSignal(n *centrifuge.Node) {
	// Create a channel to receive signals.
	sigCh := make(chan os.Signal, 1)
	// Create a channel to indicate when the shutdown is complete.
	done := make(chan bool, 1)
	// Notify the channel for SIGINT and SIGTERM signals.
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	// Start a goroutine to wait for the signal.
	go func() {
		<-sigCh
		// Shutdown the centrifuge node.
		_ = n.Shutdown(context.Background())
		// Indicate that the shutdown is complete.
		done <- true
	}()
	// Wait for the shutdown to complete.
	<-done
}

// authMiddleware is a middleware function that adds credentials to the request context before passing it to the next handler.
// It sets the user ID, expiration time, and user information in the credentials.
// The middleware function takes in a http.Handler and returns a http.Handler.
func authMiddleware(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		newCtx := centrifuge.SetCredentials(ctx, &centrifuge.Credentials{
			UserID:   "42",
			ExpireAt: time.Now().Unix() + 10,
			Info:     []byte(`{"name": "Test User"}`),
		})
		r = r.WithContext(newCtx)
		h.ServeHTTP(w, r)
	})
}

// main function initializes a new Centrifuge node and sets up event handlers for client connections, subscriptions, and RPCs.
// It also sets up a websocket handler and a file server for serving static files.
// The function waits for an exit signal before shutting down the node and exiting.
func Centrifuge() (*centrifuge.Node, error) {
	logLevel := centrifuge.LogLevelInfo

	logHandler := func(e centrifuge.LogEntry) {
		log.Printf("%s: %v", e.Message, e.Fields)
	}
	node, _ := centrifuge.New(centrifuge.Config{
		LogLevel:   logLevel,
		LogHandler: logHandler,
		Version:    "0.0.0",
		Name:       "echo",
	})

	node.OnConnecting(func(ctx context.Context, e centrifuge.ConnectEvent) (centrifuge.ConnectReply, error) {
		return centrifuge.ConnectReply{
			Data: []byte(`{}`),
		}, nil
	})

	node.OnConnect(func(client *centrifuge.Client) {
		transport := client.Transport()
		log.Printf("[user %s] connected via %s with protocol: %s", client.UserID(), transport.Name(), transport.Protocol())

		go func() {
			err := client.Send([]byte("hello"))
			if err != nil {
				if err == io.EOF {
					return
				}
				log.Fatalf("Error sending message to [user %s]: %v", client.UserID(), err.Error())
			}
		}()

		client.OnRefresh(func(e centrifuge.RefreshEvent, cb centrifuge.RefreshCallback) {
			log.Printf("[user %s] connection is going to expire, refreshing", client.UserID())
			cb(centrifuge.RefreshReply{
				ExpireAt: time.Now().Unix() + 10,
			}, nil)
		})

		client.OnSubscribe(func(e centrifuge.SubscribeEvent, cb centrifuge.SubscribeCallback) {
			log.Printf("[user %s] subscribes on %s", client.UserID(), e.Channel)
			cb(centrifuge.SubscribeReply{}, nil)
		})

		client.OnUnsubscribe(func(e centrifuge.UnsubscribeEvent) {
			log.Printf("[user %s] unsubscribed from %s", client.UserID(), e.Channel)
		})

		client.OnMessage(func(e centrifuge.MessageEvent) {
			log.Printf("[user %s] async message: %s", client.UserID(), string(e.Data))
			client.Send(e.Data /* []byte("got your message") */) // echo back
		})

		client.OnPublish(func(e centrifuge.PublishEvent, cb centrifuge.PublishCallback) {
			log.Printf("[user %s] publishes into channel %s: %s", client.UserID(), e.Channel, string(e.Data))
			cb(centrifuge.PublishReply{}, nil)
		})

		client.OnRPC(func(e centrifuge.RPCEvent, cb centrifuge.RPCCallback) {
			log.Printf("[user %s] sent RPC, data: %s, method: %s", client.UserID(), string(e.Data), e.Method)
			switch e.Method {
			case "getCurrentYear":
				cb(centrifuge.RPCReply{Data: []byte(`{"year": "2020"}`)}, nil)
			default:
				cb(centrifuge.RPCReply{}, centrifuge.ErrorMethodNotFound)
			}
		})

		client.OnDisconnect(func(e centrifuge.DisconnectEvent) {
			log.Printf("user %s disconnected, disconnect: %s", client.UserID(), e.Disconnect)
		})
	})

	if err := node.Run(); err != nil {
		return nil, err
	}

	return node, nil
}

// main function initializes a new Centrifuge node and sets up event handlers for client connections, subscriptions, and RPCs.
// It also sets up a websocket handler and a file server for serving static files.
// The function waits for an exit signal before shutting down the node and exiting.
func main() {
	// Установка временной зоны по умолчанию в UTC
	time.Local = time.UTC

	// Инициализация Centrifuge
	node, err := Centrifuge()
	if err != nil {
		log.Fatalf("Centrifuge start error: %v", err)
		os.Exit(1)
	}

	// Serve Websocket connections using WebsocketHandler.
	wsHandler := centrifuge.NewWebsocketHandler(node, centrifuge.WebsocketConfig{})
	http.Handle("/connection/websocket", authMiddleware(wsHandler))

	// The second route is for serving index.html file.
	//http.Handle("/", http.FileServer(http.Dir("./")))

	log.Printf("Starting server, http://localhost:8000/connection/websocket")
	if err := http.ListenAndServe(":8000", nil); err != nil {
		log.Fatal(err)
	}

	log.Printf("Service started")

	// Wait for an exit signal before shutting down the node and exiting.
	waitExitSignal(node)

	log.Printf("Server stopped")
	os.Exit(0)
}
