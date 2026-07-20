# 🔒 LOCKDOWN

> Build a prison so tight nobody gets out — then let real players spawn in and try.
> Design the cells, walls, and cameras; catch the tunnels, contraband, and breakouts.
> Prison Architect's cat-and-mouse, built for Roblox.

| | |
|---|---|
| 🎯 **Genre** | Management / Tycoon |
| 🧩 **Vibe** | Chill & creative (with escape drama) |
| 👥 **Mode** | Solo + co-op + break-out PvP |
| 📱 **Targets** | PC & mobile |

## 🚨 The hook

There are already a bunch of "prison tycoons" on Roblox. To win you need one thing they don't have: **the prison you build isn't just decoration — it gets tested for real.**

You build and run a max-security prison from the top-down view… then real players can spawn into it as inmates and actually try to break out, first-person and live. Your job as warden is to design a prison nobody can beat. Every prison gets an **Escape-Proof rating** (escapes ÷ attempts) and a spot on a global leaderboard.

Prison Architect lets you fight AI escapes alone — Lockdown turns it into a multiplayer game of *"nobody escapes MY prison."*

## 🎮 The current build: grid placement system

Players build their prison **piece by piece on their own plot**: open the build menu (🔨/B), pick an asset, aim the snapping ghost preview, click to place, R to rotate, 🗑️ to demolish. Layouts cloud-save and rebuild on rejoin.

The map and the buildable assets are **hand-made in Studio by the owner** — the code finds them by convention (a `PlotZones` folder for build areas, a `Buildables` folder for placeable models, see [docs/BUILDING_ASSETS.md](docs/BUILDING_ASSETS.md)) and auto-generates a flat test map only until the real one exists. Free building for now; prices and income wire back in next.

Get running: **[SETUP.md](SETUP.md)** — no coding anywhere, promise.

## 📂 What's in this repo

| Doc | What it's for |
|---|---|
| [SETUP.md](SETUP.md) | Click-by-click: install, run the demo, sync code into YOUR map, publish |
| [docs/BUILDING_ASSETS.md](docs/BUILDING_ASSETS.md) | **Your handbook** — how to make the map and buildable assets in Studio |
| `Lockdown.rbxlx` | Quick demo build (auto test map) — your real game lives in your own place file |
| `src/` + `default.project.json` | All the game code (Luau, organized by [Rojo](https://rojo.space)) — Claude's department |
| [docs/WHO_DOES_WHAT.md](docs/WHO_DOES_WHAT.md) | How we build this together — Claude writes all the code, you playtest & publish |
| [docs/GAME_PLAN.md](docs/GAME_PLAN.md) | The full design doc — core loop, systems, Roblox-only features, themes, monetization |
| [docs/ROADMAP.md](docs/ROADMAP.md) | The build roadmap (Phases 0–7) as a tickable checklist — the working to-do list |
| [docs/ESCAPE_IDEAS.md](docs/ESCAPE_IDEAS.md) | Living notes doc of every escape type + its counter, so no idea gets lost |

## 🗓️ Start this week

Don't try to do the whole roadmap — just get moving:

- **Day 1–2:** Install Roblox Studio, make your group, do one beginner tutorial.
- **Day 3–4:** Build the Phase 1 MVP — one cell button, one inmate, cash going up.
- **Day 5:** Get one friend to play it. Watch what confuses them.
- **Anytime:** Add every escape idea to [docs/ESCAPE_IDEAS.md](docs/ESCAPE_IDEAS.md) so you don't lose them.

## 📏 Golden rules

- **Ship small, then grow.** A small game that's finished and fun beats a huge game that never launches.
- **First upgrade in under ~90 seconds.** Fast early wins hook players in the first five minutes.
- **Chill, never punishing.** A successful escape is a fun event you recover from — recapture, patch the weak spot — not a game-over.
- **Lightweight inmates from day one.** Custom stripped-down rigs, not default Humanoids — smooth crowds on phones are make-or-break.
- **Cosmetic-first monetization.** Free players can still win; paying makes it comfier or prettier.

---

*The "spawn in and try to escape my prison" idea is the ace — nobody else on Roblox nails it.* 🔓
