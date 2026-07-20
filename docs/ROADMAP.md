# 🗺️ Lockdown — Build Roadmap

**The #1 rule for actually finishing a game: build the tiniest playable version first, then add layers.** Don't build everything at once. Each phase is a real, shippable step — you can publish after Phase 1 and grow. Tick things off as you go. 🎉

> GitHub renders these checkboxes — open this file on GitHub and edit it (or commit changes) to tick items off as you build.

---

## Phase 0 — Setup & learn *(~1 week)*

Get comfy in Roblox Studio before building the real thing.

> **Superseded for the coding parts** — Claude writes all the code (see [WHO_DOES_WHAT.md](WHO_DOES_WHAT.md)), so the tutorials and hello-world are optional. Your only must-do items are installing Studio and making the group. The click-by-click guide is [SETUP.md](../SETUP.md).

- [ ] Install Roblox Studio; make a Roblox group to publish the game under
- [ ] ~~Do 1–2 beginner tutorials~~ *(optional now — Claude codes)*
- [x] Learn how saving works (DataStores) — *handled: Claude built cloud saving in Phase 1*
- [x] Build a throwaway "hello world" — *skipped ahead: Phase 1 is the real thing*

## Phase 1 — MVP: the core money loop 🚀 *shippable*

Smallest fun thing: buy cell → inmate → earns cash → buy another. Nothing else yet.

- [x] One plot with a baseplate and a "buy" button for a cell — *6 walled plots, walk-on buy pad (works on phones too)*
- [x] Buying a cell spawns an inmate that pays cash on a timer — *$2/sec each, 22 cells with rising prices*
- [x] Build the inmate as a **lightweight custom rig** (not a default character) — *6 anchored parts, no Humanoid, client-side idle sway, distance culling*
- [x] Cash counter UI that goes up; buttons to buy more cells — *smooth count-up HUD, floating +$ popups, income/sec line*
- [x] Save/load the player's cash and cells — *cloud DataStore save on leave + 60s autosave + shutdown save*
- [ ] Playtest with a friend. Is expanding fun on its own? Fix until "yes" — **← your move!**

## Phase 2 — Needs & staff foundation

Give inmates simple needs and hire your first guard & cook.

- [ ] Add Food + Sleep need meters (just two to start)
- [ ] Build kitchen/canteen & beds that fill those needs
- [ ] Hire a Cook and a Guard (daily wages come out of your cash)
- [ ] Add soft "unrest" when needs are ignored — recoverable, never game-over
- [ ] Add the other needs (hygiene, recreation, safety) once two feel good

## Phase 3 — Escape & security ❤ *the heart (your hook!)*

Build the cat-and-mouse that makes the game different from every other prison tycoon.

- [ ] Pick ONE escape type to start (e.g. fence-climbing) and make inmates attempt it
- [ ] Add the counter for it (a wall + a patrolling guard + a camera)
- [ ] Alarm + a Lockdown button when an escape is spotted; recapture the inmate
- [ ] Track an Escape-Proof rating (escapes ÷ attempts) shown on screen
- [ ] Once it's fun, add a second escape type (tunnels or contraband) + its counter

## Phase 4 — Real depth: tiers, contraband, automation, prestige

The stuff that keeps players for weeks instead of minutes.

- [ ] Security tiers (Min → Med → Max) that unlock craftier, higher-paying inmates
- [ ] Contraband + searches (metal detectors, sniffer dogs)
- [ ] An upgrade/research tree (branching, not one straight line)
- [ ] First automation: guard patrol routes, auto-search checkpoints
- [ ] Prestige "New Posting" reset with permanent perks

## Phase 5 — Roblox magic: Break Out mode 🚀 *big update*

The multiplayer features that make it go viral.

- [ ] Break Out mode: let a player spawn into a prison as an inmate and try to escape it live
- [ ] Co-op: friends join to build & guard your prison together
- [ ] Attempt other players' prisons + a global Escape-Proof leaderboard
- [ ] 1–2 unlockable themes + decoration items
- [ ] Alarms, sound effects, music, satisfying build feedback

## Phase 6 — Monetize & launch 🚀 *go live*

Ship it to the world.

- [ ] Add 2–3 fair gamepasses + 1–2 dev products (cosmetic-first!)
- [ ] Make a clean game icon + thumbnail (this hugely affects clicks)
- [ ] Write a short, clear description leading with the "break out of my prison" hook
- [ ] Playtest on mobile — most Roblox players are on phones
- [ ] Publish it public. You made a game! 🎉

## Phase 7 — Grow it *(the real work starts here)*

Games grow through updates & community, not one launch.

- [ ] Make a Roblox group + Discord so players can gather
- [ ] Watch how people play; fix the boring/confusing parts
- [ ] Ship regular small updates + new escape types & events
- [ ] Add codes / rewards to bring players back

---

## 🗓️ What to actually do this week

Don't try to do the whole roadmap — just get moving:

- [ ] **Day 1–2:** Install Studio, make your group, do one beginner tutorial
- [ ] **Day 3–4:** Build the Phase 1 MVP — one cell button, one inmate, cash going up
- [ ] **Day 5:** Get one friend to play it. Watch what confuses them
- [ ] **Anytime:** Add every escape idea to [ESCAPE_IDEAS.md](ESCAPE_IDEAS.md) so you don't lose them

> **Biggest tip of all:** a small game that's finished and fun beats a huge game that never launches. Ship small, then grow. The "spawn in and try to escape my prison" idea is the ace — nobody else on Roblox nails it. 🔓
