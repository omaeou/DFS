# Example DFS plugin

This is a minimal external QML module illustrating the DFS plugin contract.

To enable it, edit `shell/config.json`:

1. Set `plugins.example-clock.enabled` to `true`.
2. Add `"example-clock"` to one of `bar.layout.left`, `bar.layout.center`, or `bar.layout.right`.
3. Restart/reload Quickshell if the source file was newly added.

Plugin components must expose `moduleId` (string), `settings` (object), and `theme` (object) properties. A plugin used in the control panel must also expose `panel` (host object) and implement only the documented methods it needs. API version 1 is registered with `apiVersion: 1`.

Plugins are trusted QML code. They run with the permissions of the current user; do not install or enable code from unknown sources. Automatic plugin discovery and permission sandboxing are not implemented yet.
