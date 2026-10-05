package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
)

type HyprEvent struct {
	Event string `json:"event"`
	Data  string `json:"data"`
}

var (
	clients = make(map[*websocket.Conn]bool)
	clientsMu sync.Mutex
	broadcast = make(chan HyprEvent)
)

var upgreder = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func main() {
	log.Print("Starting DFS Daemon (Dark Fantasy Shell) pid: ", os.Getpid())

	go handleMessages()

	go func() {
		http.HandleFunc("/ws", handleConnections)
		log.Println("WebSocket server started on ws://localhost:7777/ws")
		err := http.ListenAndServe(":7777", nil)
		if err != nil {
			log.Fatalf("WebSocket server failed: %v", err)
		}
	}()

	listenHyprland()
}




func listenHyprland() {

hyprSignature := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	if hyprSignature == "" {
		log.Fatal("HYPRLAND_INSTANCE_SIGNATURE is not set. Are you running under Hyprland?")
	}

	xdgRuntimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if xdgRuntimeDir == "" {
		log.Fatal("XDG_RUNTIME_DIR is not set. Are you running under a proper environment?")
	}

	var socketPath string

	if xdgRuntimeDir != "" {
		socketPath = fmt.Sprintf("%s/hypr/%s/.socket2.sock", xdgRuntimeDir, hyprSignature)
	} else {
		socketPath = fmt.Sprintf("/tmp/hypr/%s/.socket2.sock", hyprSignature)
	}
	

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		log.Fatalf("Failed to connect to Hyprland IPC: %v", err)
	}
	defer conn.Close()

	log.Printf("Connected to Hyprland IPC socket at %s", socketPath)

	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		line := scanner.Text()
		parseAndBroadcast(line)
	}
}


func parseAndBroadcast(rawEvent string) {
	part := strings.SplitN(rawEvent, ">>", 2)
	if len(part) != 2 {
		return
	}

	eventName := part[0]
	eventData := part[1]

	switch eventName {
	case "workspace", "focusedmonv2", "activewindow", "window", "monitor", "input", "layout", "barconfig", "bind", "shutdown", "reload", "unknown":
		fmt.Printf("Received event: %s with data: %s\n", eventName, eventData)
		broadcast <- HyprEvent{Event: eventName, Data: eventData}
	}
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgreder.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}
	defer ws.Close()

	clientsMu.Lock()
	clients[ws] = true
	clientsMu.Unlock()

	log.Printf("New WebSocket client connected: %v", ws.RemoteAddr())

	for {
		_, _, err := ws.ReadMessage()
		if err != nil {
			clientsMu.Lock()
			delete(clients, ws)
			clientsMu.Unlock()
			log.Printf("WebSocket client disconnected: %v", ws.RemoteAddr())
			break
		}
	}
}

func handleMessages() {
	for {
		msg := <-broadcast
		clientsMu.Lock()
		for client := range clients {
			err := client.WriteJSON(msg)
			if err != nil {
				client.Close()
				delete(clients, client)
			}
		}
		clientsMu.Unlock()
	}
}