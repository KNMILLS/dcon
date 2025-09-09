# Milestone 0 — Stabilize Foundation

- [x] CCTV SubViewport set to 640×360, UPDATE_ALWAYS, CLEAR_MODE_ALWAYS
- [x] ViewportCamera current; feed binds to drone Camera3D and follows transform
- [x] Input actions verified: WASD, Q/E, zoom_in/out, zoom_feed, possess_toggle, escape_release
- [x] FOV clamps between min/max; +/- and wheel adjust smoothly
- [x] Debug logging gated by `enable_debug_logging` in Drone/CCTVMonitor/OperatorConsole
- [x] TestStation has `DroneSpawn` and basic collisions; auto-spawn works
- [x] Automated validation run; screenshots captured

Controls quick reference
- WASD: move
- Mouse (possessed): look
- Q/E: rotate
- +/- or wheel: FOV
- R: monitor zoom
- Tab: possess/release
- Esc: release
