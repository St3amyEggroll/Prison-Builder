# 🔒 Lockdown — Game Design Plan

Build a prison so tight nobody gets out — then let real players spawn in and try. Prison Architect's cat-and-mouse, built for Roblox.

- 🎯 **Genre:** Management / Tycoon
- 🧩 **Vibe:** Chill & creative (with escape drama)
- 👥 **Mode:** Solo + co-op + break-out PvP
- 📱 **Targets:** PC & mobile

---

## ◆ The Big Idea (the hook)

There are already a bunch of "prison tycoons" on Roblox. To win you need one thing they don't have. Ours is that **the prison you build isn't just decoration — it gets tested for real.**

> 🚨 **The hook** — You build and run a max-security prison from the top-down view… then real players can spawn into it as inmates and actually try to break out, first-person and live. Your job as warden is to design a prison nobody can beat. Every prison gets an **Escape-Proof rating** (escapes ÷ attempts) and a spot on a global leaderboard. Prison Architect lets you fight AI escapes alone — this turns it into a multiplayer game of "nobody escapes MY prison."

Three pillars:

- 🧠 **A building puzzle** — The creative fun is designing sneaky, escape-proof layouts: walls, sightlines, choke points, camera coverage.
- 🐿️ **Cat & mouse** — Inmates are always scheming: tunnels, contraband, riots. You build the counters. Constant tension.
- 🏆 **Bragging rights** — "0 escapes in 500 attempts." A leaderboard for the most unbreakable prison on Roblox.

> **On "chill & creative":** it stays relaxed and forgiving — no harsh game-over. A successful escape is a fun event you recover from (recapture, patch the weak spot), not a loss. The thrill is the escape *theme*; the pace is cozy builder.

---

## ◆ Why this can beat Prison Architect

Keep PA's deep security sim and add everything Roblox does better — most of all, **real people trying to escape your build**.

| Feature | Prison Architect | Lockdown |
|---|---|---|
| Who tries to escape your prison | ✗ AI only | ✓ real players, live |
| Play AS the escaping inmate | ~ solo mode only | ✓ multiplayer, first-person |
| Guard with friends | ✗ solo | ✓ co-op warden + guards |
| Prove your prison is unbeatable | ✗ none | ✓ global Escape-Proof leaderboard |
| Cost & access | paid PC game | free, instant, on phone too |
| Deep security & logistics | ✓ deep | ✓ keep it — just friendlier |

We're not out-simulating PA. We're taking its best part — outsmarting escapes — and turning it into a social, free, phone-friendly Roblox game.

---

## ◆ The core gameplay loop

1. **Claim a plot** → start with a small yard, a wall, and a bit of cash.
2. **Build intake + cells + a perimeter** (bars, walls, a gate).
3. **Inmates arrive** → each pays a daily grant for being locked up. Higher security = higher pay.
4. **They start scheming** → probing for weak spots (tunnels, contraband, fences, riots).
5. **You build security & foil attempts** → guards, cameras, detectors, lockdowns.
6. **Keep your Escape-Proof rating high** → more funding, tougher (higher-paying) inmates.
7. **Reinvest & expand** → bigger prison, higher security tiers.
8. **Prestige ("New Posting")** → a fresh prison biome + permanent perks. Loop restarts, deeper.

> **The golden rule:** a brand-new player should afford their first upgrade in under ~90 seconds. Fast early wins are what hook people in the first five minutes.

---

## ◆ Escape attempts vs. your counters

**This table is the game.** Every way inmates try to break out has a thing you build or manage to stop it. That back-and-forth is the whole hook — start with one or two rows and add more over time. (Living version: [ESCAPE_IDEAS.md](ESCAPE_IDEAS.md))

| 🏃 How they try to escape | 🛡️ How you stop it |
|---|---|
| Digging tunnels from cells & showers | Floor sensors, concrete foundations, guard patrols, routine cell searches |
| Smuggling contraband (keycards, tools, files) | Metal detectors, sniffer dogs, searches at intake & after visits |
| Climbing / cutting the fence | High walls, razor wire, watchtowers, floodlights, sensor fences |
| Starting a riot as a distraction | Keep needs met, enough guards, riot squad, the big red Lockdown button |
| Hiding in work crews / laundry / deliveries | Headcounts, exit checkpoints, search-on-leave |
| Jumping a lone guard | Patrol in pairs, camera coverage, panic buttons |

---

## ◆ The systems under the hood

### 🧍 Inmate needs (why a happy prison is a secure prison)

Simple meters — Food, Sleep, Hygiene, Recreation, Safety. Ignore them and unrest rises → riots → escape openings. So meeting needs isn't just nice, it's security. Keep it forgiving: unrest is a fixable setback, never an instant loss.

> ⚡ **Performance — make inmates CUSTOM lightweight humanoids, not default characters.** A busy prison can have dozens of inmates on screen at once, and Roblox's full `Humanoid` is heavy — each one runs physics and a state machine, and a crowd of them will lag phones hard. Use stripped-down custom rigs: turn off the `HumanoidStateType`s you don't need, use simple R6 rigs, and for background/idle inmates consider CFrame + animation only (no real Humanoid at all). **Build this in from day one — retrofitting it later is a nightmare.** Smooth crowds are make-or-break for a management game.

### 🛠️ The security toolkit

- 👮 **Guards & patrols** — assign routes, checkpoints, and pairs.
- 📹 **CCTV + camera room** — coverage and a spot to watch it all.
- 🚪 **Sec doors & keycards** — zone the prison; control who goes where.
- 🔍 **Detectors & dogs** — catch contraband before it spreads.
- 🗼 **Watchtowers & walls** — lock down the perimeter.
- 🚨 **Lockdown button** — freeze everything when it goes sideways.

### 🔒 Security tiers = the progression ladder

Minimum → Medium → Maximum → Supermax. Each tier brings craftier, higher-paying inmates that need better security to hold. There's always a next goal.

### 👷 Staff you hire

Guards (containment) · Cooks (food) · Janitors (hygiene) · Doctors (health) · Dog handlers & camera operators (security) · Managers (unlock automation later). Wages come out daily, so growth is a balancing act.

### 💰 Where money comes from

| Income source | How it works |
|---|---|
| Daily grants | Steady cash per inmate held — more for higher security. The baseline. |
| Recapture bounties | Catch an escapee (or a player who breaks out) → bonus reward. |
| Contraband seizures | Confiscated tools & goods sell for cash. |
| Prison labor | Work crews craft goods you sell (the classic license-plate money-maker). |
| Rating bonuses | A high Escape-Proof rating unlocks bigger government funding. |

### ⚙️ Automation (the depth that keeps people playing for weeks)

Once players are established, let them automate: set patrol routes, auto-search at checkpoints, camera-room alerts, smart doors, power & lighting grids. Now the game becomes a fun spatial puzzle — "how do I cover every angle?" — instead of a grind.

### ♻️ Prestige — "New Posting"

When a prison is maxed, let players transfer to a brand-new biome (see Themes) and reset — keeping permanent perks (a % income boost, free starter guards, exclusive security gear). Make prestige a reward, never a paywall.

---

## ◆ Signature Roblox-only features

The stuff Prison Architect literally can't do. Even one or two of these makes the game blow up.

- 🏃‍♂️ **Break Out mode** — Spawn into any prison — yours or a stranger's — as an inmate and try to escape it live, first-person. **THE differentiator.**
- ⚔️ **Warden vs Inmates (PvP)** — Some players build & guard, others try to break out. Cops-and-robbers meets tycoon = chaos + fun.
- 🌍 **Escape-Proof leaderboard** — Global ranking of the hardest prisons to escape. Free marketing when people flex their builds.
- 🎞️ **Escape replays** — Watch exactly how a breakout went down, then patch the weak spot. Super satisfying.
- 🤝 **Co-op guarding** — Invite friends to run the prison with you — build together, sound the alarm together.
- 📸 **Photo mode** — Snap your fortress and share it. Screenshots = free ads.

---

## ◆ Prison themes / biomes

Unlockable settings that reskin the whole prison and add fresh escape challenges. Great for prestige rewards and cosmetic gamepasses.

- 🧱 **Classic Blocks** — The starter — brick, bars, floodlights.
- 🏝️ **Alcatraz Island** — Surrounded by water — where do you even run?
- 🚀 **Orbital Supermax** — A prison in space. No air outside = no escape.
- 🏔️ **Arctic Blacksite** — Freezing wilderness for miles.
- 🕳️ **Underground Vault** — Buried deep — tunneling is the whole game.
- 🏜️ **Desert Rock** — Open sightlines, nowhere to hide.

---

## ◆ Making money the fair way

Roblox players punish greedy games hard. Keep it **cosmetic-first** and **never pay-to-win** and you keep players (and the algorithm) on your side.

### ✅ Good gamepasses (one-time)

- Extra build plots / bigger prison
- Cosmetic theme packs & decorations
- VIP: name tag, small daily cash bonus, exclusive skins
- Auto-collect income while you build
- Extra guard or camera slots

### 🧾 Dev products (repeatable)

- Cash boost packs
- Instant-build tokens (skip a timer once)
- Event / limited cosmetic gear

> **Avoid the trap:** if a game needs 5+ "auto-everything" passes just to be playable, players bounce. Free players should still be able to win — paying just makes it comfier or prettier.

---

## ◆ Name ideas

Lean into the escape/security fantasy and avoid the crowded "___ Prison Tycoon" names:

1. **Lockdown** ★ (top pick)
2. Supermax
3. No Way Out
4. Escape-Proof
5. Unbreakable
6. Cellblock
7. The Big House
8. Contained

> **Tip:** search the name in Roblox first to make sure it isn't taken, and check it reads well squished onto a game icon.

---

*Build roadmap lives in [ROADMAP.md](ROADMAP.md) — tick things off as you go.* 💪
