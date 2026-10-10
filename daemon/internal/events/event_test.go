package events

import "testing"

func TestParseHyprland(t *testing.T) {
	tests := []struct {
		name string
		line string
		want Event
		ok   bool
	}{
		{name: "workspace", line: "workspace>>3", want: Event{Event: "workspace", Data: "3"}, ok: true},
		{name: "data may contain delimiter", line: "activewindow>>app,title>>suffix", want: Event{Event: "activewindow", Data: "app,title>>suffix"}, ok: true},
		{name: "unknown event", line: "not-real>>data", ok: false},
		{name: "malformed", line: "workspace", ok: false},
		{name: "empty event", line: ">>data", ok: false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := ParseHyprland(tt.line)
			if ok != tt.ok || got != tt.want {
				t.Fatalf("ParseHyprland(%q) = (%+v, %v), want (%+v, %v)", tt.line, got, ok, tt.want, tt.ok)
			}
		})
	}
}
