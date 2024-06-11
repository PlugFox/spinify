package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	log "log"
	"os"
	"os/signal"
	"slices"
	"strconv"
	"time"

	"io"
	"net/http"
	"syscall"

	"github.com/centrifugal/centrifuge"
)

var port = flag.Int("port", 8000, "Port to bind app to")

type clientMessage struct {
	Timestamp int64  `json:"timestamp"`
	Input     string `json:"input"`
}

// waitExitSignal waits for the SIGINT or SIGTERM signal to shutdown the centrifuge node.
// It creates a channel to receive signals and a channel to indicate when the shutdown is complete.
// Then it notifies the channel for SIGINT and SIGTERM signals and starts a goroutine to wait for the signal.
// Once the signal is received, it shuts down the centrifuge node and indicates that the shutdown is complete.
func waitExitSignal(n *centrifuge.Node, s *http.Server, sigCh chan os.Signal) {
	// Create a channel to indicate when the shutdown is complete.
	done := make(chan bool, 1)
	// Notify the channel for SIGINT and SIGTERM signals.
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	// Start a goroutine to wait for the signal.
	go func() {
		// Wait for the signal.
		<-sigCh
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = n.Shutdown(ctx)
		_ = s.Shutdown(ctx)
		done <- true
	}()
	// Wait for the shutdown to complete.
	<-done
}

var channels = []string{"public:index", "chat:index"}

// Check whether channel is allowed for subscribing. In real case permission
// check will probably be more complex than in this example.
func channelSubscribeAllowed(channel string) bool {
	return slices.Contains(channels, channel)
}

// authMiddleware is a middleware function that adds credentials to the request context before passing it to the next handler.
// It sets the user ID, expiration time, and user information in the credentials.
// The middleware function takes in a http.Handler and returns a http.Handler.
func authMiddleware(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		newCtx := centrifuge.SetCredentials(ctx, &centrifuge.Credentials{
			UserID:   "42",
			ExpireAt: time.Now().Unix() + 25,
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
	logHandler := func(e centrifuge.LogEntry) {
		log.Printf("%s: %v", e.Message, e.Fields)
	}
	node, _ := centrifuge.New(centrifuge.Config{
		LogLevel:       centrifuge.LogLevelInfo,
		LogHandler:     logHandler,
		Version:        "0.0.0",
		Name:           "echo",
		HistoryMetaTTL: 24 * time.Hour,
	})

	node.OnConnecting(func(ctx context.Context, e centrifuge.ConnectEvent) (centrifuge.ConnectReply, error) {
		cred, _ := centrifuge.GetCredentials(ctx)
		return centrifuge.ConnectReply{
			Data:              []byte(`{}`),
			ClientSideRefresh: false,
			// Subscribe to a personal server-side channel.
			Subscriptions: map[string]centrifuge.SubscribeOptions{
				"#" + cred.UserID: {
					EnableRecovery: true,
					EmitPresence:   false,
					EmitJoinLeave:  false,
					PushJoinLeave:  false,
				},
				"notification:index": {
					EnableRecovery: true,
					EmitPresence:   false,
					EmitJoinLeave:  false,
					PushJoinLeave:  false,
				},
			},
		}, nil
	})

	node.OnConnect(func(client *centrifuge.Client) {
		transport := client.Transport()
		log.Printf("[user %s] connected via %s with protocol: %s", client.UserID(), transport.Name(), transport.Protocol())

		// Event handler should not block, so start separate goroutine to
		// periodically send messages to client.
		go func() {
			for {
				select {
				case <-client.Context().Done():
					return
				case <-time.After(60 * time.Second):
					// Periodically send message to client.
					err := client.Send([]byte(`{"time": "` + strconv.FormatInt(time.Now().Unix(), 10) + `"}`))
					if err != nil {
						if err == io.EOF {
							return
						}
						log.Printf("[user %s] error sending message: %s", client.UserID(), err)
					}
				}
			}
		}()

		client.OnRefresh(func(e centrifuge.RefreshEvent, cb centrifuge.RefreshCallback) {
			// Prolong connection lifetime from client-side refresh.
			/* if e.ClientSideRefresh {
				log.Printf("[user %s] refresh connection from client with token '%s'", client.UserID(), e.Token)
				cb(centrifuge.RefreshReply{ExpireAt: time.Now().Unix() + 25}, nil)
			} else {
				log.Printf("[user %s] connection is going to expire", client.UserID())
			} */

			log.Printf("[user %s] refresh connection", client.UserID())
			cb(centrifuge.RefreshReply{ExpireAt: time.Now().Unix() + 25}, nil)
		})

		client.OnSubscribe(func(e centrifuge.SubscribeEvent, cb centrifuge.SubscribeCallback) {
			log.Printf("[user %s] subscribes on %s", client.UserID(), e.Channel)

			if !channelSubscribeAllowed(e.Channel) {
				cb(centrifuge.SubscribeReply{}, centrifuge.ErrorPermissionDenied)
				return
			}

			cb(centrifuge.SubscribeReply{
				Options: centrifuge.SubscribeOptions{
					EnableRecovery: true,
					EmitPresence:   true,
					EmitJoinLeave:  true,
					PushJoinLeave:  true,
					Data:           []byte(`{"msg": "welcome"}`),
				},
			}, nil)
		})

		client.OnMessage(func(e centrifuge.MessageEvent) {
			log.Printf("[user %s] async message: %s", client.UserID(), string(e.Data))
			client.Send(e.Data /* []byte("got your message") */) // echo back
		})

		client.OnPublish(func(e centrifuge.PublishEvent, cb centrifuge.PublishCallback) {
			log.Printf("[user %s] publishes into channel %s: %s", client.UserID(), e.Channel, string(e.Data))

			if !client.IsSubscribed(e.Channel) {
				cb(centrifuge.PublishReply{}, centrifuge.ErrorPermissionDenied)
				return
			}

			var msg clientMessage
			err := json.Unmarshal(e.Data, &msg)
			if err != nil {
				cb(centrifuge.PublishReply{}, centrifuge.ErrorBadRequest)
				return
			}
			msg.Timestamp = time.Now().Unix()
			data, _ := json.Marshal(msg)

			result, err := node.Publish(
				e.Channel, data,
				centrifuge.WithHistory(300, time.Minute),
				centrifuge.WithClientInfo(e.ClientInfo),
			)

			cb(centrifuge.PublishReply{Result: &result}, err)
		})

		client.OnRPC(func(e centrifuge.RPCEvent, cb centrifuge.RPCCallback) {
			log.Printf("[user %s] sent RPC, data: %s, method: %s", client.UserID(), string(e.Data), e.Method)
			switch e.Method {
			case "getCurrentYear":
				// Return current year.
				cb(centrifuge.RPCReply{Data: []byte(`{"year": ` + strconv.Itoa(time.Now().Year()) + `}`)}, nil)
			case "echo":
				// Return back input data.
				cb(centrifuge.RPCReply{Data: e.Data}, nil)
			default:
				// Method not found.
				cb(centrifuge.RPCReply{}, centrifuge.ErrorMethodNotFound)
			}
		})

		client.OnPresence(func(e centrifuge.PresenceEvent, cb centrifuge.PresenceCallback) {
			log.Printf("[user %s] calls presence on %s", client.UserID(), e.Channel)

			if !client.IsSubscribed(e.Channel) {
				cb(centrifuge.PresenceReply{}, centrifuge.ErrorPermissionDenied)
				return
			}
			cb(centrifuge.PresenceReply{}, nil)
		})

		client.OnUnsubscribe(func(e centrifuge.UnsubscribeEvent) {
			log.Printf("[user %s] unsubscribed from %s: %s", client.UserID(), e.Channel, e.Reason)
		})

		client.OnAlive(func() {
			log.Printf("[user %s] connection is still active", client.UserID())
		})

		client.OnDisconnect(func(e centrifuge.DisconnectEvent) {
			log.Printf("[user %s] disconnected: %s", client.UserID(), e.Reason)
		})
	})

	if err := node.Run(); err != nil {
		log.Fatal(err)
		return nil, err
	}

	go func() {
		// Publish personal notifications for user 42 periodically.
		i := 1
		for {
			_, err := node.Publish(
				"#42",
				[]byte(`{"personal": "`+strconv.Itoa(i)+`"}`),
				centrifuge.WithHistory(300, time.Minute),
			)
			if err != nil {
				log.Printf("error publishing to personal channel: %s", err)
			}
			i++
			time.Sleep(1 * time.Minute)
		}
	}()

	go func() {
		// Publish to channel periodically.
		i := 1
		for {
			_, err := node.Publish(
				"notification:index",
				[]byte(`{"input": "Publish from server `+strconv.Itoa(i)+`"}`),
				centrifuge.WithHistory(300, time.Minute),
			)
			if err != nil {
				log.Printf("error publishing to channel: %s", err)
			}
			i++
			time.Sleep(1 * time.Minute)
		}
	}()

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

	mux := http.DefaultServeMux

	// Serve Websocket connections using WebsocketHandler.
	websocketHandler := centrifuge.NewWebsocketHandler(node, centrifuge.WebsocketConfig{
		ReadBufferSize:     1024,
		UseWriteBufferPool: true,
	})
	mux.Handle("/connection/websocket", authMiddleware(websocketHandler))

	//mux.Handle("/metrics", promhttp.Handler())
	//mux.Handle("/", http.FileServer(http.Dir("./")))

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// Create a channel to shutdown the server.
	sigCh := make(chan os.Signal, 1)

	// Shutdown the node when /exit endpoint is hit.
	mux.HandleFunc("/exit", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
		// Close after 1 sec to let response go to client.
		time.AfterFunc(time.Second, func() {
			sigCh <- syscall.SIGTERM // Close server.
		})
	})

	server := &http.Server{
		Handler:      mux,
		Addr:         ":" + strconv.Itoa(*port),
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	go func() {
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
			os.Exit(1)
		}
	}()

	log.Printf("Server is running, http://localhost:8000/connection/websocket")

	// Wait for an exit signal before shutting down the node and exiting.
	waitExitSignal(node, server, sigCh)

	log.Printf("Server stopped")
	os.Exit(0)
}
