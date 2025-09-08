## **Game Design Document: *dcon***

### **1. Executive Summary**

**Title:** *dcon*
**Genre & Vision:** Atmospheric survival-ops simulator—part tactical drone management, part psychological horror. The player is a remote human operator managing fragile, sentient drone packages drifting through alien structures. No menus. No saving.

**Core Experience Goals:**

* Immersion through diegetic interface—“connecting” feels real.
* Emotional connection to drones through naming, uniqueness, and fragility.
* Psychological tension via resource stress (memory limits) and system decay.

**Target Audience:**
Solo-first, narrative-suspense players; fans of immersive sim and roguelike tension.

---

### **2. Design Pillars**

| Pillar                        | Description                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------------ |
| **Fidelity**                  | Hyper-realistic camera feeds and visual artifacts create tangible atmosphere.        |
| **Attachment**                | Drones are unique and nameable: losing one hurts emotionally.                        |
| **Tension Through Fragility** | Memory is finite—overloading or distraction leads to glitches, hallucinations, loss. |
| **Seamless Diegetic Flow**    | No traditional UI—everything is part of the system you inhabit.                      |

---

### **3. Core Loops & Player Journey**

**Session Flow:**

1. Game boots directly into fullscreen start-up “CONNECTING...” terminal scene.
2. Transition to the drone management console with live feeds and drone statuses.
3. The player either manually pilots a drone (WASD + mouse) or monitors multiple feeds.
4. Memory reallocation and switching draws risk—other drones degrade or even vanish.
5. Naming new discoveries builds attachment; losing drones intensifies emotional weight.
6. Exiting ends the session—ephemeral world reset next launch.

**Primary Loop:**

* Observe → Decide → Act (pilot/monitor) → Manage memory → Respond to degradation → Emotional payoff.

---

### **4. Mechanics Breakdown**

* **Scene Flow:**

  * **StartupLink.tscn** – Fullscreen terminal with typewriter-style green text, then fades.
  * **OperatorConsole.tscn** – Main scene: drone list, feed window, status overlays.

* **Drone Entity:**

  * **Unique Attributes:** name, health, camera type (thermal, wide-angle, audio, etc.).
  * **Memory Pool:** finite capacity to run tasks; when filled, performance degrades, glitch shaders activate.

* **Control Systems:**

  * **Manual:** WASD and mouse for active drone.
  * **Auto:** Others run autonomous tasks; unattended risk accumulates with memory strain.

* **Feed System:**

  * Multi-view architecture via `SubViewport`s.
  * Feed toggle via UI button or key (e.g., Tab).

* **Memory Stress Dynamics:**

  * Memory usage slows tasks, injects distortion, glitches UI, and spawns ghost frames—reflecting psychological decay.

* **Naming & Emotional Bonding:**

  * New drone acquisition triggers a minimalist overlay to name it.
  * Player identity and emotion reflected in dialogue or feed quirks tied to the drone’s name.

* **Permanent Ephemerality:**

  * On exit, game state resets. Only UI-related settings might persist via ConfigFile.

---

### **5. Aesthetic & Narrative Themes**

* **Visual Style:** Cinematic feeds with film grain, dynamic focus, subtle lens artefacts.
* **Sound Design:** Ambient hums, static glitches, muted creaks—minimalistic but haunting.
* **Emotion:** Emotional layering through naming and loss; grief framed as a gameplay mechanic.
* **Story Beats:** Hints of forgotten Earth, lost missions, and eerie AI signals appear through logs and corrupted recordings.

---

### **6. Technical Architecture**

```
/scenes
  StartupLink.tscn
  OperatorConsole.tscn
  Drone.tscn
  CCTVMonitor.tscn
/ui
  NamingOverlay.tscn
/scripts
  startup_link.gd
  operator_console.gd
  drone.gd
  drone_memory.gd
  feed_switcher.gd
  naming_overlay.gd
/shaders
  glitch_under_load.gdshader
  cinematic_post.fx
```

* **Input Map:**

  * `move_forward/back/left/right`, `toggle_feed`, `possess_next_drone`, `zoom_feed`, `close` etc.

* **Memory System:**

  * `DroneMemory.gd` with signals to drive UI patches and shader uniforms.

* **Post Effects:**

  * `glitch_under_load.gdshader` on feed texture.
  * Slight CRT/film layer for atmosphere.

---

### **7. UI Structure**

* **Operator Console Layout:**

  * Left: Drone list (name, memory usage, status).
  * Center: Feed display (TextureRect).
  * Top: Status bar (session timer, signal strength).
  * Overlay: Naming prompt; ghost overlays on memory stress.

---

### **8. Development Roadmap**

| Milestones            | Goals                                                 |
| --------------------- | ----------------------------------------------------- |
| Foundation Setup      | Startup scene + Operator Console + basic drone entity |
| Feed Loop             | SubViewport feeds + toggle switching                  |
| Movement + Possession | WASD + mouse pilot for drone                          |
| Memory & Glitch FX    | Memory pool logic + feed shaders                      |
| Naming UI             | Name drone on acquisition                             |
| Emotional Layer       | Loss feedback; feed ghosting; audio fragile hints     |
| Polish                | Visual filters, ambient sound design, node clean-up   |

---

### **9. Practical GDD Philosophy**

This GDD is modern and utilitarian—concise, modular, and living. It balances clarity with flexibility, giving agents or collaborators direct spec without immersion-breaking detail. Each section is actionable, aligned to features, and reflects modern game design best practices.
([codecks.io][1], [Game Developer][2])
