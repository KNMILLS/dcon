## *dcon* — Lean Game Design Document (Updated)

### 1. **Game Concept**

An ultra‑realistic remote operations simulation: you authenticate into a deep‑space link and assume control of a probe‑borne drone that touched down inside a derelict space station. Through a degraded, sensor‑driven video feed, you explore, salvage, and survive. The experience is intentionally diegetic, systems‑first, and inspired by DUSKERS: creative problem‑solving under incomplete information, accumulating capability by upgrading a single drone—the drone is the character—while a hostile station ecosystem pushes back. There’s no conventional save—sessions are ephemeral to heighten tension and immersion.

**Key Hooks:**

* **VISOR vision**: stylized sensor modes (edge detect, thermal palette, optional CRT) define your perception.
* **Drone as you**: only one camera—your drone’s—and memory constraints shape your experience.
* **Minimal UI**: diegetic interface—no titles, no menus, just connection → naming → control → decay.

---

### 2. **Core Loop & Player Journey**

| Stage              | Actions & Experience |
| ------------------ | ------------------- |
| **Connect**        | Scrollable boot/auth logs → connect to Operator Console. Drone is auto‑named (random callsign) and immediately controllable. |
| **Scan**           | Use basic sensors to map nearby corridors/doors; identify signals, hazards, and salvage targets. |
| **Breach**         | Route power/open doors or bypass locks; accept risk (noise, exposure). |
| **Explore**        | WASD/mouse to pilot within a sensor‑mediated feed; manage visibility and fidelity under memory/power constraints. |
| **Salvage**        | Recover resources and claim derelict drones; run integrity checks before activation. |
| **Upgrade**        | Install modules (sensors, memory, shielding, comms) with trade‑offs (power/heat/memory). |
| **Survive/Retreat**| React to hazards and threats; extract when overwhelmed. No mid‑run saves. |

---

### 3. **Mechanics & Technical Systems**

#### Drone Entity

* `Drone.tscn` as `CharacterBody3D` with collision.
* `Camera3D` child runs script (`drone_camera.gd`) to manage `current`, FOV zoom, and exposure.
* Possession toggles mouse capture; non‑possessed drones still stream for monitoring.

#### Drone Progression

* Upgrade the single drone by installing modules (sensors, memory capacity, shielding, comms range/bandwidth) with trade‑offs (power/heat/memory footprint).
* Contextual tasks increase memory/power demand; careful routing and timing are required to avoid overloads.

#### Hostile Station Systems

* Environmental hazards: vacuum breaches, radiation spikes, corrosives, EMP surges.
* Active threats: rogue maintenance bots, sentry turrets, security subsystems.
* Systems layer: power routing, doors/locks, air handling—believable failure modes and alarms; interacting with systems can reveal pathways or trigger threats.

#### Operator Constraints

* Signal quality and latency affect input responsiveness and feed clarity.
* Memory and power are primary resources; high pressure increases visual glitching and reduces effective sensor fidelity.
* Diegetic diagnostics (signal strength, latency, memory use) are surfaced in the console/HUD.

#### Feed Rendering (Current Build)

* A single **SubViewport** (forced 640×360, UPDATE_ALWAYS, CLEAR_MODE_ALWAYS).
* The **drone camera** (`CameraPivot/Camera3D`) is bound at runtime; monitor mirrors its transform.
* UI uses a **SubViewportContainer** (`CCTVMonitor.tscn`) with a simple debug readout.

#### Sensor FX (VISOR Style)

* Planned: Sobel Edge and Thermal LUT modes (glitch shader temporarily disabled while stabilizing feed).
* Mode hotkeys reserved (`1/2/0`).
* Memory/power pressure will modulate distortion once shaders are re‑enabled.

#### Memory/Power Feedback

* `set_memory_pressure(ratio)` updates shader intensity and task cadence.
* Optional power budget gates certain modules; overdraw triggers emergency cutbacks.

#### Input (Current Build)

* Movement: WASD; mouse look while possessed.
* Zoom: monitor scale toggle only (camera FOV zoom pending).
* Sensor modes: not yet wired.
* Additional: release possession; page up/down adjust memory load (for testing).
* Proper InputMap configuration, optionally added at runtime if missing.

---

### 4. **Visual & UX Design**

* **Terminal‑first**: scrollable boot/auth logs (typewriter; debug skip supported) lead into the diegetic Operator Console.
* **Sensor aesthetics**: purposefully abstract (VISOR‑style), prioritizing legibility under stress over photorealism.
* **Environment blocks**: simple geometry (floors, corridors, walls) with fog and tone mapping to emphasize silhouette and depth; expands with systems/hazards.
* **UI**: minimal, diegetic HUD—sensor mode (EDGE/THRM/NONE), FOV/zoom level, memory ratio, signal/latency; optional debug shows viewport size/camera state.
* **Audio**: persistent station hums; sensor/actuator coil whine; distinct overload snaps/glitches scaling with memory/power stress and signal quality.

---

### 5. **Technical Stack & Structure**

```
/scenes
  Drone.tscn
  StartupLink.tscn
  OperatorConsole.tscn
  CCTVMonitor.tscn
/scripts
  drone_camera.gd
  OperatorConsole.gd
  CCTVMonitor.gd
/shaders
  sobel_edge.gdshader
  thermal_lut.gdshader
  crt_overlay.gdshader
```

* **Camera Pipeline**: Camera3D → SubViewport → ViewportTexture → TextureRect.
* **Shader pipeline**: dynamic mode switching + memory-integrated glitch intensity.
* **Iterative prototyping**: Starting from simple blockout scenes; polish visuals incrementally once gameplay feels solid. (\[turn0search1], \[turn0search3])

---

### 6. **Design Philosophy & Iterative Approach**

This GDD is intentionally **minimal and actionable**, following modern agile and iterative design practices that favor working prototypes over lengthy spec. Feedback from the actual build drives the next evolution. (\[turn0search3], \[turn0search1])

**Principles:**

* Build fast, test sooner. Don’t lock visuals first—nail the feeling and control loop.
* Let the game prototype be the primary design artifact—update this doc as the gameplay proves itself.
* Break the GDD into small, modular features—sensor modes, camera control, memory UX—so individual agents or developers can own them clearly.

---

### 7. **Roadmap**

#### MVP
* Single drone with collision, possession, and basic movement/looking.
* Stable SubViewport feed; re‑enable glitch shader; add two sensor modes (EDGE/THRM).
* Operator Console: boot/auth logs (speed‑tuned), auto‑naming, minimal HUD (mode/memory/signal).
* Simple hazards and basic salvage/resources for upgrades; camera FOV zoom.

#### Post‑MVP
* Station subsystems (power routing, doors/locks, air) with believable failure modes.
* Active threats (rogue bots, sentries) and environmental hazards (radiation/EMP/corrosives).
* Deeper upgrade trees and trade‑offs (memory, shielding, comms bandwidth/range).
* Procedural station expansion; deployable sensor nodes; richer audio design.

---

### References & Context

* Modern GDDs should remain **lean and evolving**; over-specifying hurts more than helps. (\[turn0search3], \[turn0search6])
* Iteration is key—“make playable, then improve.” (*Ori*’s process is a strong example.) (\[turn0search1])
* GDD is a **living document**, updated as design and code align. (\[turn0search4], \[turn0search10])

