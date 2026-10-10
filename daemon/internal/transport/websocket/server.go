package websocket

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"dfs-daemon/internal/events"
	ws "github.com/gorilla/websocket"
)

const (
	writeWait     = 5 * time.Second
	pongWait      = 60 * time.Second
	pingPeriod    = (pongWait * 9) / 10
	maxReadBytes  = 1024
	clientQueue   = 64
	publishBuffer = 128
)

// Server exposes the stable event contract to the QML client over loopback-only WebSocket IPC.
type Server struct {
	address string
	logger  *log.Logger
	mu      sync.Mutex
	clients map[*client]struct{}
	publish chan events.Event
	http    *http.Server
}

type client struct {
	conn *ws.Conn
	send chan []byte
	done chan struct{}
	once sync.Once
}

func NewServer(address string, logger *log.Logger) (*Server, error) {
	if err := validateLoopbackAddress(address); err != nil {
		return nil, err
	}
	if logger == nil {
		logger = log.Default()
	}
	return &Server{
		address: address,
		logger:  logger,
		clients: make(map[*client]struct{}),
		publish: make(chan events.Event, publishBuffer),
	}, nil
}

func validateLoopbackAddress(address string) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return fmt.Errorf("invalid DFS_DAEMON_ADDR %q: %w", address, err)
	}
	if strings.EqualFold(host, "localhost") {
		return nil
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("DFS daemon must bind to a loopback address; got %q", address)
	}
	return nil
}

func (s *Server) Publish(event events.Event) {
	// If a consumer stalls, keep the stream moving and discard the oldest
	// queued event rather than blocking the compositor event reader forever.
	select {
	case s.publish <- event:
	default:
		select {
		case <-s.publish:
		default:
		}
		select {
		case s.publish <- event:
		default:
		}
	}
}

func (s *Server) Run(ctx context.Context) error {
	upgrader := ws.Upgrader{
		HandshakeTimeout: 5 * time.Second,
		CheckOrigin: func(r *http.Request) bool {
			return isLoopbackRemote(r.RemoteAddr) && isAllowedOrigin(r.Header.Get("Origin"))
		},
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		s.handleConnections(w, r, &upgrader)
	})
	s.http = &http.Server{
		Addr:              s.address,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 * 1024,
	}

	listener, err := net.Listen("tcp", s.address)
	if err != nil {
		return fmt.Errorf("listen on %s: %w", s.address, err)
	}
	s.logger.Printf("DFS WebSocket IPC listening at ws://%s/ws (loopback only)", s.address)
	go s.broadcastLoop(ctx)
	serveErr := make(chan error, 1)
	go func() {
		err := s.http.Serve(listener)
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
			return
		}
		serveErr <- nil
	}()

	select {
	case <-ctx.Done():
		s.closeClients()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = s.http.Shutdown(shutdownCtx)
		return nil
	case err := <-serveErr:
		s.closeClients()
		return err
	}
}

func (s *Server) handleConnections(w http.ResponseWriter, r *http.Request, upgrader *ws.Upgrader) {
	if !isLoopbackRemote(r.RemoteAddr) {
		http.Error(w, "loopback clients only", http.StatusForbidden)
		return
	}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		s.logger.Printf("WebSocket upgrade failed: %v", err)
		return
	}
	c := &client{conn: conn, send: make(chan []byte, clientQueue), done: make(chan struct{})}
	s.mu.Lock()
	s.clients[c] = struct{}{}
	s.mu.Unlock()

	s.logger.Printf("WebSocket client connected: %s", conn.RemoteAddr())
	go c.writePump(s)
	c.readPump(s)
}

func (c *client) readPump(s *Server) {
	defer s.removeClient(c)
	c.conn.SetReadLimit(maxReadBytes)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(pongWait))
	})
	for {
		if _, _, err := c.conn.ReadMessage(); err != nil {
			return
		}
	}
}

func (c *client) writePump(s *Server) {
	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()
	defer s.removeClient(c)
	for {
		select {
		case <-c.done:
			return
		case message := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(ws.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(ws.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (s *Server) broadcastLoop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case event := <-s.publish:
			payload, err := json.Marshal(event)
			if err != nil {
				s.logger.Printf("Unable to serialize IPC event: %v", err)
				continue
			}
			s.mu.Lock()
			for c := range s.clients {
				select {
				case c.send <- payload:
				case <-c.done:
				default:
					// A slow consumer must not stall every other client.
					go s.removeClient(c)
				}
			}
			s.mu.Unlock()
		}
	}
}

func (s *Server) removeClient(c *client) {
	c.once.Do(func() {
		s.mu.Lock()
		delete(s.clients, c)
		s.mu.Unlock()
		close(c.done)
		_ = c.conn.Close()
		s.logger.Printf("WebSocket client disconnected")
	})
}

func (s *Server) closeClients() {
	s.mu.Lock()
	clients := make([]*client, 0, len(s.clients))
	for c := range s.clients {
		clients = append(clients, c)
	}
	s.mu.Unlock()
	for _, c := range clients {
		s.removeClient(c)
	}
}

func isLoopbackRemote(remoteAddress string) bool {
	host, _, err := net.SplitHostPort(remoteAddress)
	if err != nil {
		return false
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

func isAllowedOrigin(origin string) bool {
	if origin == "" || origin == "null" || origin == "file://" {
		return true
	}
	parsed, err := url.Parse(origin)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") {
		return false
	}
	host := parsed.Hostname()
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
