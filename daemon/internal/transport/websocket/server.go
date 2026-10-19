package websocket

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
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
	maxClients    = 8
	publishBuffer = 128
)

// Server exposes the stable event contract to the QML client over loopback-only WebSocket IPC.
type Server struct {
	address string
	logger  *log.Logger
	token   string
	mu      sync.Mutex
	clients map[*client]struct{}
	slots   chan struct{}
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
		slots:   make(chan struct{}, maxClients),
		publish: make(chan events.Event, publishBuffer),
	}, nil
}

func validateLoopbackAddress(address string) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return fmt.Errorf("invalid DFS_DAEMON_ADDR %q: %w", address, err)
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("DFS daemon must bind to a loopback IP literal; got %q", address)
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

func (s *Server) Run(ctx context.Context, tokenPath string) error {
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
	token, err := writeAuthToken(tokenPath)
	if err != nil {
		_ = listener.Close()
		return err
	}
	s.token = token
	defer removeAuthToken(tokenPath, token)
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
	if !isAllowedOrigin(r.Header.Get("Origin")) {
		http.Error(w, "origin not allowed", http.StatusForbidden)
		return
	}
	if !authTokenMatches(r.URL.Query().Get("token"), s.token) {
		http.Error(w, "authentication required", http.StatusForbidden)
		return
	}
	select {
	case s.slots <- struct{}{}:
	default:
		http.Error(w, "too many local clients", http.StatusServiceUnavailable)
		return
	}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		<-s.slots
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
			slowClients := make([]*client, 0)
			s.mu.Lock()
			for c := range s.clients {
				select {
				case c.send <- payload:
				case <-c.done:
				default:
					// Remove slow consumers after releasing the map lock. Creating
					// a goroutine per dropped event could grow without a bound.
					slowClients = append(slowClients, c)
				}
			}
			s.mu.Unlock()
			for _, c := range slowClients {
				s.removeClient(c)
			}
		}
	}
}

func (s *Server) removeClient(c *client) {
	c.once.Do(func() {
		s.mu.Lock()
		delete(s.clients, c)
		s.mu.Unlock()
		<-s.slots
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
	// Quickshell is a native peer and needs no browser origin. A web page on
	// localhost or an opaque `null` origin must not be able to read window titles.
	return origin == "" || origin == "file://"
}

func authTokenMatches(candidate, expected string) bool {
	return expected != "" && subtle.ConstantTimeCompare([]byte(candidate), []byte(expected)) == 1
}

func writeAuthToken(path string) (string, error) {
	if !filepath.IsAbs(path) || filepath.Base(path) == "." || filepath.Base(path) == string(filepath.Separator) {
		return "", errors.New("WebSocket token path must be absolute and name a file")
	}
	dir := filepath.Dir(path)
	dirInfo, err := os.Lstat(dir)
	if err != nil {
		return "", fmt.Errorf("inspect WebSocket token directory %q: %w", dir, err)
	}
	if dirInfo.Mode()&os.ModeSymlink != 0 || !dirInfo.IsDir() ||
		dirInfo.Mode().Perm()&0o077 != 0 || dirInfo.Mode().Perm()&0o700 != 0o700 {
		return "", errors.New("WebSocket token directory must be a private directory with mode 0700")
	}
	stat, ok := dirInfo.Sys().(*syscall.Stat_t)
	if !ok || int(stat.Uid) != os.Geteuid() {
		return "", errors.New("WebSocket token directory must be owned by the current user")
	}

	randomBytes := make([]byte, 32)
	if _, err := rand.Read(randomBytes); err != nil {
		return "", fmt.Errorf("generate WebSocket token: %w", err)
	}
	token := hex.EncodeToString(randomBytes)
	temporary, err := os.CreateTemp(dir, ".dfs-websocket-token-*")
	if err != nil {
		return "", fmt.Errorf("create WebSocket token file: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return "", fmt.Errorf("protect WebSocket token file: %w", err)
	}
	if _, err := io.WriteString(temporary, token+"\n"); err != nil {
		_ = temporary.Close()
		return "", fmt.Errorf("write WebSocket token file: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return "", fmt.Errorf("close WebSocket token file: %w", err)
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return "", fmt.Errorf("publish WebSocket token file: %w", err)
	}
	return token, nil
}

func removeAuthToken(path, token string) {
	contents, err := os.ReadFile(path)
	if err != nil || !authTokenMatches(strings.TrimSpace(string(contents)), token) {
		return
	}
	_ = os.Remove(path)
}
