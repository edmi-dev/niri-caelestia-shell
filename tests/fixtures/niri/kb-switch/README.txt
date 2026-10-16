scenario: kb-switch
recorded: isolated headless sway + nested niri (winit), config tests/fixtures/niri/config.kdl
niri: niri 26.04 (Nixpkgs)
actions:
niri msg action switch-layout next
niri msg action switch-layout next
niri msg action switch-layout 1
