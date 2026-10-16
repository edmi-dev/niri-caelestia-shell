scenario: fullscreen
recorded: isolated headless sway + nested niri (winit), config tests/fixtures/niri/config.kdl
niri: niri 26.04 (Nixpkgs)
actions:
niri msg action fullscreen-window
niri msg action fullscreen-window
niri msg action toggle-windowed-fullscreen
niri msg action toggle-windowed-fullscreen
