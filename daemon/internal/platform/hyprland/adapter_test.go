package hyprland

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSocketPathFromEnv(t *testing.T) {
	runtimeDir := t.TempDir()
	if err := os.Chmod(runtimeDir, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "instance-test")
	t.Setenv("XDG_RUNTIME_DIR", runtimeDir)

	got, err := SocketPathFromEnv()
	if err != nil {
		t.Fatalf("SocketPathFromEnv returned error: %v", err)
	}
	want := filepath.Join(runtimeDir, "hypr", "instance-test", ".socket2.sock")
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

func TestSocketPathFromEnvRequiresAbsoluteRuntimeDir(t *testing.T) {
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "instance-test")
	t.Setenv("XDG_RUNTIME_DIR", "relative/runtime")
	if _, err := SocketPathFromEnv(); err == nil {
		t.Fatal("expected relative runtime directory to fail")
	}
}

func TestSocketPathFromEnvRequiresRuntimeDir(t *testing.T) {
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "instance-test")
	t.Setenv("XDG_RUNTIME_DIR", "")
	if _, err := SocketPathFromEnv(); err == nil {
		t.Fatal("expected missing XDG_RUNTIME_DIR to fail without a /tmp fallback")
	}
}

func TestSocketPathFromEnvRejectsUnsafeSignatureCharacters(t *testing.T) {
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "instance;touch-owned-file")
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	if _, err := SocketPathFromEnv(); err == nil {
		t.Fatal("expected a signature with shell punctuation to fail")
	}
}

func TestSocketPathFromEnvRejectsInsecureRuntimeDir(t *testing.T) {
	runtimeDir := t.TempDir()
	if err := os.Chmod(runtimeDir, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "instance-test")
	t.Setenv("XDG_RUNTIME_DIR", runtimeDir)
	if _, err := SocketPathFromEnv(); err == nil {
		t.Fatal("expected a runtime directory accessible by others to fail")
	}
}
