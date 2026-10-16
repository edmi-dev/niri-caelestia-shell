scenario: windows
recorded: isolated headless sway + nested niri (winit), config tests/fixtures/niri/config.kdl
niri: niri 26.04 (Nixpkgs)
actions:
niri msg action focus-column-left
niri msg action focus-column-first
niri msg action move-column-right
niri msg action consume-or-expel-window-left
niri msg action close-window
niri msg action focus-column-last
