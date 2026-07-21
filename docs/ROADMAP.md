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

## ✅ Phase 2 — Buildings & working doors 🏗️ *(shipped)*

Make structures real, not decorative. Unlocks the Foundations tab.

- [x] Foundations tool: drag a rectangle → perimeter walls + floor build themselves (uses the `Wall` / `Floor Tile` assets)
- [x] Doors that open — slide down for the warden when they walk close; solid for everyone else (`Door` attribute + `DoorPanel` part convention)
- [x] Enclosure detection: a room is "enclosed" when every square around it is walls/doors
- [x] Room requirements, PA-style: the floor label shows "needs: surround with walls + a door, 1× housing" until satisfied, then "✓ ready" — re-checked live as you build
- [x] Undo (Ctrl+Z / ↩) for placements, lines, foundations, and bulldozes
- [x] Move tool (✋): pick up a placed object and re-place it (Ctrl+Z puts it back)
- [x] Mouse aim fix: ghost/bulldoze now lands exactly under the cursor (GUI-inset ray bug)
- [x] Category drag styles: walls & doors (and custom categories) drag **lines**, flooring **fills rectangles**, objects stay click-to-place; bulldoze drags a delete-rectangle
- [x] Build-mode grid overlay, place/demolish sounds, right-click cancels selection
- [ ] Owner playtest: build a real enclosed cell block with a door and watch the labels go green — **← your move!**

## ✅ Phase 3 — Money, construction crews & pathfinding 💰 *(shipped)*

The economy returns, plus PA's construction feel — and pathfinding, pulled forward from Phase 4 (owner's call).

- [x] Prices live: `Price` attribute (category defaults otherwise); placing charges, bulldozing refunds 50%, undo refunds 100%, blueprints refund in full. `Config.FreeBuild` = owner sandbox switch
- [x] Grants: each housed prisoner pays $60 / 30s; cash HUD with count-up, ±$ blips, income/min and session +/- report; cash on the player list
- [x] Workmen: placements become blue see-through blueprints; each plot's 2-man crew pathfinds over and hammers them real (blueprints don't count for capacity, enclosure, or rooms until built). `Config.InstantBuild` skips it
- [x] **A* pathfinding on the build grid**: escorts and workmen walk around walls and through doors; unreachable cells leave arrivals waiting with a "⚠ no door path" warning; doors auto-open for walking NPCs
- [x] Starter objectives (PA grants): build walls → paint a Cell → get it ✓ ready → house 3 → earn $5k, with rewards and a progress card
- [x] Move tool reworked: true server-side move — free, instant, Ctrl+Z moves it back
- [ ] Owner playtest: watch a workman build your wall line, and an arrival walk the corridor to their cell — **← your move!**

## Phase 4 — Prisoner life: needs, regime & staff 👮

The sim under the hood. Unlocks the Staff tab.

- [x] ~~Real pathfinding~~ — shipped early in Phase 3
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
