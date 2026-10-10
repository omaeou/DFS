package hyprland

import (
	"path/filepath"
	"testing"
)

func TestSocketPathFromEnv(t *testing.T) {
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "instance-test")
	t.Setenv("XDG_RUNTIME_DIR", "/run/user/1000")

	got, err := SocketPathFromEnv()
	if err != nil {
		t.Fatalf("SocketPathFromEnv returned error: %v", err)
	}
	want := filepath.Join("/run/user/1000", "hypr", "instance-test", ".socket2.sock")
	if got != want {
		t.Fatalf("SocketPathFromEnv() = %q, want %q", got, want)
	}
}

func TestSocketPathFromEnvRequiresSignature(t *testing.T) {
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "")
	if _, err := SocketPathFromEnv(); err == nil {
		t.Fatal("expected missing signature to fail")
	}
}

func TestSocketPathFromEnvRejectsPathTraversal(t *testing.T) {
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "../other-session")
	if _, err := SocketPathFromEnv(); err == nil {
		t.Fatal("expected path-like signature to fail")
	}
}
