# 🗺️ Lockdown — Build Roadmap

> 🔄 **Re-scoped (owner's call):** we are building a full Prison Architect-style sim on Roblox first — building, money, prisoner life, security, escapes — and THEN adding the one thing PA can never have: real players breaking out of your prison, live. Phases 2–6 are the PA copy; Phase 7 is the ace.

**The #1 rule still stands: each phase is a real, shippable step.** Tick things off as you go. 🎉

Who does what: Claude writes all the code; you build the map & assets in Studio ([BUILDING_ASSETS.md](BUILDING_ASSETS.md)), playtest every phase, and make the calls. Update ritual: `git pull` → `rojo serve` → Connect.

---

## ✅ Phase 1 — The Builder *(shipped)*

The Prison Architect building experience, reading YOUR map and YOUR assets.

- [x] Grid placement: snapping ghost preview, green/red validity, 90° rotation, PC + touch
- [x] Drag-to-build lines for 1-square assets, auto-rotated along the drag
- [x] Room painter: pick the type first, drag a rectangle; colored floor + **names written on the floor** (flood-filled regions); eraser
- [x] PA-style bottom toolbar (Walls & Doors / Flooring / Rooms / Objects / Bulldoze + grayed future tabs); assets sort by `Category` attribute, new names auto-create buttons
- [x] Top-down tilted build camera: WASD/two-finger pan, scroll/pinch zoom, Q/E rotate
- [x] Intake: 🚔 menu (accept + auto-fill), arrivals wait **handcuffed at the plot front**, get escorted to empty housing, then wander their home
- [x] Lightweight custom-rig inmates (no Humanoids) with procedural walk/idle/cuffed animation, distance-culled
- [x] Owner conventions: `PlotZones` (build areas anywhere in your map) + `Buildables` (any Model = menu item), replaceable placeholders, cloud saving of layout + rooms + intake
- [ ] Owner: first version of the real map (`PlotZones` + SpawnLocation) — **← your move!**
- [ ] Owner: first custom assets in `Buildables`
- [ ] Playtest with a friend. Is building fun on its own? Fix until "yes"

## Phase 2 — Buildings & working doors 🏗️

Make structures real, not decorative. Unlocks the Foundations tab.

- [ ] Foundations tool: drag a rectangle → perimeter walls + floor build themselves (PA quick-build)
- [ ] Doors that open — for the warden and staff; inmates blocked (the first real security boundary)
- [ ] Enclosure detection: walls + a door = a building (indoor/outdoor)
- [ ] Room requirements, PA-style: a painted Cell says "needs a bed, must be enclosed" until satisfied
- [ ] Undo (Ctrl+Z) for place/bulldoze
- [ ] Move tool: pick up a placed object and re-place it

## Phase 3 — Money & construction crews 💰

The economy returns, plus PA's construction feel.

- [ ] Prices: the `Price` attribute goes live; placing costs cash, bulldozing refunds a cut
- [ ] Daily grants per prisoner held; cash HUD returns (count-up, +$ popups)
- [ ] Workmen: placements become blueprint ghosts that construction workers walk over and build
- [ ] Starter objectives ("build 10 cells → $5,000") — PA grants, simplified
- [ ] Simple cashflow report (income vs. wages)

## Phase 4 — Prisoner life: needs, regime & staff 👮

The sim under the hood. Unlocks the Staff tab.

- [ ] **Real pathfinding** — prisoners walk around walls, through doors (escorts upgraded from straight lines too)
- [ ] Needs meters: Food, Sleep, Hygiene, Recreation, Safety
- [ ] Regime schedule: hour-by-hour day (sleep → eat → yard → lockup), prisoners follow it
- [ ] The food chain: Kitchen room + Cook staff → meals in the Canteen
- [ ] Staff with daily wages: Guards, Cooks, Janitors
- [ ] Soft unrest when needs are ignored — recoverable, never game-over

## Phase 5 — Security & escapes ❤ *(the heart)*

The cat-and-mouse that IS the game.

- [ ] Contraband: smuggled tools/keycards; metal detectors + cell searches to catch it
- [ ] Escape attempt #1: fence climbing — and its counters (walls, patrols, cameras)
- [ ] Escape attempt #2: tunnels from cells — floor sensors, foundations, searches
- [ ] Alarm + the big red **Lockdown** button; recapture with bounty
- [ ] **Escape-Proof rating** (escapes ÷ attempts) on screen
- [ ] Guard patrol routes (PA Deployment, simplified)
- [ ] Security tiers: Min → Med → Max prisoners — higher pay, craftier schemes

## Phase 6 — PA polish & depth ✨

- [ ] Day/night cycle tied to the regime
- [ ] Fights & riots + riot squad response
- [ ] More rooms gaining meaning: Shower, Yard, Workshop (prison labor income), Office
- [ ] Reports menu (population, needs, security, money — PA's reports folder)
- [ ] Sound, music, and build juice everywhere

## Phase 7 — The Roblox ace: Break Out 🚀 *(what PA can never do)*

- [ ] Break Out mode: a real player spawns in as an inmate and tries to escape, first-person
- [ ] Co-op: friends join as guards/co-wardens on your prison
- [ ] Attempt strangers' prisons + global Escape-Proof leaderboard
- [ ] Escape replays: watch how they got out, patch the hole
- [ ] 1–2 unlockable themes + decorations

## Phase 8 — Monetize & launch 🚀

- [ ] 2–3 fair gamepasses + 1–2 dev products (cosmetic-first, never pay-to-win)
- [ ] Clean icon + thumbnail; description leading with "break out of my prison"
- [ ] Mobile polish pass on a real phone
- [ ] Publish public 🎉

## Phase 9 — Grow it 🌱

- [ ] Roblox group + Discord
- [ ] Watch strangers play; fix the confusing/boring parts
- [ ] Regular updates: new escape types, events, rooms
- [ ] Redeem codes & comeback rewards

---

> **Biggest tip of all, unchanged:** a small game that's finished and fun beats a huge game that never launches. Every phase above ships something playable. The escape-ideas notebook lives in [ESCAPE_IDEAS.md](ESCAPE_IDEAS.md) — keep feeding it. 🔓
