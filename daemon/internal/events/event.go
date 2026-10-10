package events

// Event is the stable event envelope exposed to the shell over IPC.
type Event struct {
	Event string `json:"event"`
	Data  string `json:"data"`
}

var supportedHyprlandEvents = map[string]struct{}{
	"workspace":    {},
	"focusedmonv2": {},
	"activewindow": {},
	"window":       {},
	"monitor":      {},
	"input":        {},
	"layout":       {},
	"barconfig":    {},
	"bind":         {},
	"shutdown":     {},
	"reload":       {},
	"unknown":      {},
}

// ParseHyprland parses the event format used by Hyprland's .socket2.sock.
// Unknown events and malformed lines are ignored to keep the IPC contract stable.
func ParseHyprland(raw string) (Event, bool) {
	name, data, ok := splitEvent(raw)
	if !ok {
		return Event{}, false
	}
	if _, supported := supportedHyprlandEvents[name]; !supported {
		return Event{}, false
	}
	return Event{Event: name, Data: data}, true
}

func splitEvent(raw string) (string, string, bool) {
	for i := 0; i+1 < len(raw); i++ {
		if raw[i] == '>' && raw[i+1] == '>' {
			if i == 0 {
				return "", "", false
			}
			return raw[:i], raw[i+2:], true
		}
	}
	return "", "", false
}
