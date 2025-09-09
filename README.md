# dcon
dcon game

## Quickstart

### Controls
- Movement: W/A/S/D
- Look: keyboard only — yaw with Q/E, pitch with I/K
- Rotate: Q/E
- Zoom FOV: Mouse Wheel or +/-
- Zoom monitor scale: R
- Possess/Release: Tab (toggle possession)
- Emergency release: Esc
- VISOR modes: 1 = EDGE, 2 = THERMAL, 0 = NONE
- Memory test: PageUp/PageDown to add/release memory load

### Notes
- The Operator Console uses a SubViewport monitor bound to the drone camera.
- SubViewport is fixed at 640×360 with UPDATE_ALWAYS and CLEAR_MODE_ALWAYS.
- If the feed is black, ensure a valid `Drone` exists and its `Camera3D` is current.

### HUD
- Mode: current VISOR mode (NONE/EDGE/THERMAL)
- Memory: percentage of memory pressure (also drives glitch intensity)
- FOV: current camera FOV
- Signal/Latency: placeholder for future networking simulation
