package websocket

import "testing"

func TestValidateLoopbackAddress(t *testing.T) {
	valid := []string{"127.0.0.1:7777", "localhost:7777", "[::1]:7777"}
	for _, address := range valid {
		t.Run(address, func(t *testing.T) {
			if err := validateLoopbackAddress(address); err != nil {
				t.Fatalf("expected %q to be valid: %v", address, err)
			}
		})
	}
	invalid := []string{"0.0.0.0:7777", ":7777", "192.168.1.20:7777", "bad-address"}
	for _, address := range invalid {
		t.Run(address, func(t *testing.T) {
			if err := validateLoopbackAddress(address); err == nil {
				t.Fatalf("expected %q to be rejected", address)
			}
		})
	}
}

func TestOriginPolicy(t *testing.T) {
	allowed := []string{"", "null", "file://", "http://localhost:3000", "http://127.0.0.1:3000", "http://[::1]:3000"}
	for _, origin := range allowed {
		if !isAllowedOrigin(origin) {
			t.Errorf("expected origin %q to be allowed", origin)
		}
	}
	denied := []string{"https://example.com", "https://evil.local", "not a URL"}
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
