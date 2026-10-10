package main

import (
	"context"
	"errors"
	"log"
	"os"
	"os/signal"
	"syscall"

	"dfs-daemon/internal/platform/hyprland"
	wsipc "dfs-daemon/internal/transport/websocket"
)

const defaultAddress = "127.0.0.1:7777"

func main() {
	if err := run(); err != nil {
		log.Printf("DFS daemon stopped: %v", err)
		os.Exit(1)
	}
}

func run() error {
	address := os.Getenv("DFS_DAEMON_ADDR")
	if address == "" {
		address = defaultAddress
	}
	server, err := wsipc.NewServer(address, log.Default())
	if err != nil {
		return err
	}
	socketPath, err := hyprland.SocketPathFromEnv()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	serverErr := make(chan error, 1)
	go func() { serverErr <- server.Run(ctx) }()

	adapter := &hyprland.Adapter{SocketPath: socketPath, Logger: log.Default()}
	adapterErr := make(chan error, 1)
	go func() {
		adapterErr <- adapter.Run(ctx, server.Publish)
	}()

	select {
	case <-ctx.Done():
		return nil
	case err := <-serverErr:
		if ctx.Err() != nil {
			return nil
		}
		stop()
		if err != nil {
			return err
		}
		return errors.New("WebSocket server stopped unexpectedly")
	case err := <-adapterErr:
		if ctx.Err() != nil {
			return nil
		}
		stop()
		if err != nil {
			return err
		}
		return errors.New("Hyprland adapter stopped unexpectedly")
	}
}
