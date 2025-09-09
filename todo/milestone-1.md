Milestone 1 — VISOR sensor modes + glitch under load

Checklist
- [x] Add `PostFX` TextureRect to `scenes/CCTVMonitor.tscn`, bind SubViewport texture
- [x] Create `shaders/visor_post.gdshader` with modes (NONE/EDGE/THERMAL) and glitch
- [x] Wire `CCTVMonitor.gd` to use shader, implement `set_visor_mode` and `set_memory_pressure`
- [x] Add input actions 0/1/2 and call `_monitor.set_visor_mode(0|1|2)` in `OperatorConsole.gd`
- [x] Validate in editor: mode switch hotkeys, memory pressure glitch scaling, stable viewport

Notes
- SubViewport fixed at 640×360; `PostFX` stretches full-rect with `STRETCH_SCALE` and `flip_v=true`.
- Debug logs remain gated by exported flags.

