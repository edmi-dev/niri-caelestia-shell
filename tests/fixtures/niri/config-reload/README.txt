scenario: config-reload
recorded: isolated headless sway + nested niri (winit), config tests/fixtures/niri/config.kdl
niri: niri 26.04 (Nixpkgs)
actions:
niri msg action load-config-file
