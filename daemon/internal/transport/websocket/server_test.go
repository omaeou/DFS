package websocket

import (
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	ws "github.com/gorilla/websocket"
)

func TestValidateLoopbackAddress(t *testing.T) {
	valid := []string{"127.0.0.1:7777", "[::1]:7777"}
	for _, address := range valid {
		t.Run(address, func(t *testing.T) {
			if err := validateLoopbackAddress(address); err != nil {
				t.Fatalf("expected %q to be valid: %v", address, err)
			}
		})
	}
	invalid := []string{"0.0.0.0:7777", ":7777", "192.168.1.20:7777", "localhost:7777", "bad-address"}
	for _, address := range invalid {
		t.Run(address, func(t *testing.T) {
			if err := validateLoopbackAddress(address); err == nil {
				t.Fatalf("expected %q to be rejected", address)
			}
		})
	}
}

func TestOriginPolicy(t *testing.T) {
	allowed := []string{"", "file://"}
	for _, origin := range allowed {
		if !isAllowedOrigin(origin) {
			t.Errorf("expected origin %q to be allowed", origin)
		}
	}
	denied := []string{
		"null", "http://localhost:3000", "http://127.0.0.1:3000",
		"http://[::1]:3000", "https://example.com", "https://evil.local", "not a URL",
	}
	for _, origin := range denied {
		if isAllowedOrigin(origin) {
			t.Errorf("expected origin %q to be denied", origin)
		}
	}
}

func TestLoopbackRemote(t *testing.T) {
	allowed := []string{"127.0.0.1:10", "[::1]:10"}
	for _, address := range allowed {
		if !isLoopbackRemote(address) {
			t.Errorf("expected loopback remote %q", address)
		}
	}
	denied := []string{"192.168.1.2:10", "not-address"}
	for _, address := range denied {
		if isLoopbackRemote(address) {
			t.Errorf("expected non-loopback remote %q", address)
		}
	}
}

func TestRejectsConnectionsWhenClientLimitIsReached(t *testing.T) {
	server := &Server{slots: make(chan struct{}, maxClients), token: strings.Repeat("a", 64)}
	for range maxClients {
		server.slots <- struct{}{}
	}
	request := httptest.NewRequest(http.MethodGet, "http://127.0.0.1/ws?token="+server.token, nil)
	request.RemoteAddr = "127.0.0.1:12345"
	response := httptest.NewRecorder()
	server.handleConnections(response, request, &ws.Upgrader{})

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusServiceUnavailable)
	}
}

func TestAuthTokenIsRequired(t *testing.T) {
	server := &Server{slots: make(chan struct{}, maxClients), token: strings.Repeat("a", 64)}
	request := httptest.NewRequest(http.MethodGet, "http://127.0.0.1/ws", nil)
	request.RemoteAddr = "127.0.0.1:12345"
	response := httptest.NewRecorder()
	server.handleConnections(response, request, &ws.Upgrader{})
	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusForbidden)
	}
}

func TestValidTokenPassesAuthentication(t *testing.T) {
	server, err := NewServer("127.0.0.1:0", log.New(io.Discard, "", 0))
	if err != nil {
		t.Fatal(err)
	}
	server.token = strings.Repeat("b", 64)
	request := httptest.NewRequest(http.MethodGet, "http://127.0.0.1/ws?token="+server.token, nil)
	request.RemoteAddr = "127.0.0.1:12345"
	response := httptest.NewRecorder()
	server.handleConnections(response, request, &ws.Upgrader{})
	if response.Code == http.StatusForbidden {
		t.Fatal("valid token was rejected before WebSocket handshake validation")
	}
	if len(server.slots) != 0 {
		t.Fatal("failed WebSocket handshake leaked a client slot")
	}
}

func TestWriteAuthTokenUsesPrivateFile(t *testing.T) {
	dir := t.TempDir()
	if err := os.Chmod(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "token")
	token, err := writeAuthToken(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(token) != 64 || !authTokenMatches(token, token) {
		t.Fatalf("generated token has unexpected shape")
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("token file mode = %04o, want 0600", info.Mode().Perm())
	}
	if !authTokenMatches(strings.TrimSpace(string(mustReadFile(t, path))), token) {
		t.Fatal("token file does not contain the generated token")
	}
}

func mustReadFile(t *testing.T, path string) []byte {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return data
}
