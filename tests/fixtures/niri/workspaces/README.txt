scenario: workspaces
recorded: isolated headless sway + nested niri (winit), config tests/fixtures/niri/config.kdl
niri: niri 26.04 (Nixpkgs)
actions:
niri msg action focus-workspace-down
niri msg action focus-workspace two
niri msg action focus-workspace one
niri msg action move-window-to-workspace two
niri msg action focus-workspace 3
niri msg action focus-workspace-up
