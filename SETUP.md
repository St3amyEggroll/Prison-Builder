# 🎮 Setup — from zero to building prisons

No coding anywhere in this guide. There are **two ways to run the game** — the quick demo (30 seconds) and *your real game* (your own map, kept forever).

## 0. One-time installs

1. Roblox account: [roblox.com](https://www.roblox.com) → **Sign Up** (skip if you have one).
2. Roblox Studio: [create.roblox.com](https://create.roblox.com) → **Start Creating** → install → log in.
3. Rojo (you've already done this in PowerShell — if you're on a new PC, ask Claude for the install commands again).
4. The project folder: you should have `Prison-Builder` in your Downloads (from the ZIP). To get updates later, re-download the ZIP the same way.

## A. Quick demo (fastest way to try the build system)

```powershell
cd "$env:USERPROFILE\Downloads\Prison-Builder"
rojo build -o Lockdown.rbxlx
Invoke-Item .\Lockdown.rbxlx
```

Press ▶ Play. This uses an auto-generated flat test map with 4 plots and the placeholder assets — perfect for testing, but **it is not your map**. Don't build your real prison here.

## B. Your real game (do your map & assets here)

1. Open Studio → **New** → **Baseplate** template.
2. **File → Save to File As...** → save it somewhere safe, e.g. `Documents\Lockdown.rbxl`. This file is YOUR game — map, assets, everything.
3. In PowerShell:
   ```powershell
   cd "$env:USERPROFILE\Downloads\Prison-Builder"
   rojo serve
   ```
4. Back in Studio: **Plugins tab → Rojo → Connect**. The game code streams into your place (you'll see `Server` appear under ServerScriptService in the Explorer).
5. Press ▶ Play — the build system is live. Until you've made your own map it generates the flat test map; once you add a `PlotZones` folder ([docs/BUILDING_ASSETS.md](docs/BUILDING_ASSETS.md)), your map takes over.
6. Save (Ctrl+S). The code stays saved inside your place — you only need `rojo serve` + Connect again **when Claude ships a code update**.

### Getting Claude's updates into your game

1. Re-download the project ZIP from GitHub → Extract → replace your `Prison-Builder` folder.
2. `rojo serve` in the new folder → open your place → **Plugins → Rojo → Connect** → the new code syncs in → save.
   Your map and assets are untouched — Rojo only manages the code, never Workspace.

## 🎛️ The controls (in Play mode)

Opening build mode switches to the **top-down Prison Architect camera** (slightly tilted for the 2.5D feel). Closing it returns to your character.

| Action | PC | Phone |
|---|---|---|
| Open/close build mode | **B** or the 🔨 button | 🔨 button |
| Pan the camera | **WASD** / arrows | two-finger drag |
| Zoom | scroll wheel | pinch |
| Rotate camera 45° | **Q** / **E** | — |
| Pick a toolbar category (PA-style bottom bar) | 🏗️ Foundations · 🧱 Walls & Doors · 🟫 Flooring · 🎨 Rooms · 🪑 Objects · ✋ Move · 🗑️ Bulldoze · ↩ Undo | same |
| Pick an asset or room type | click its tile | tap its tile |
| **Foundation** (walls + floor in one go) | 🏗️, then drag a rectangle | same |
| **Move an object** | ✋, then click it, then place it | same |
| **Undo** | **Ctrl+Z** or ↩ | ↩ button |
| Aim the ghost preview | move mouse | drag finger |
| Place (when ghost is green) | click | tap |
| **Drag-to-build a line** (walls, fences, floors) | press, drag, release | press, drag, release |
| **Paint a room** (pick type first!) | press, drag a rectangle, release | same |
| Rotate object 90° | **R** or ↻ | ↻ button |
| Demolish mode | 🗑️ button, then click objects | 🗑️ button, then tap |
| Prisoner intake | 🚔 button → accept / auto-intake | same |

## C. One-time: make saving work (~2 minutes)

Player layouts save to Roblox's servers — but only after publishing:

1. With your place open: **File → Publish to Roblox As...** → name it `Lockdown` → **Create**.
2. Home tab → **Game Settings** → **Security** → **Enable Studio Access to API Services** → ON → **Save**.
3. Done — prisons now survive between sessions. (Until then everything plays fine but resets each time; the orange DataStore warning in Output is that, and it's harmless.)

When you publish updates later: **File → Publish to Roblox As... → select your EXISTING Lockdown game** — that's what keeps everyone's saves.

## D. Play with a friend

1. Publish first (step C).
2. **File → Game Settings → Permissions** → **Friends** (or Public) → **Save**.
3. Both of you: roblox.com → your profile → **Creations** → **Lockdown** → **Play**. Everyone gets their own plot zone.

## 🚑 Troubleshooting

| Problem | Fix |
|---|---|
| Layouts reset every session | Step C not done yet |
| Rojo "Connect" button does nothing / not there | Run `rojo plugin install` in PowerShell, restart Studio |
| `rojo serve` says port in use | An old serve is still running — close that PowerShell window first |
| Build menu is empty | Wait a moment and re-enter Play; if it persists, tell Claude |
| My model problems (floating, wrong size, not in menu) | See [docs/BUILDING_ASSETS.md](docs/BUILDING_ASSETS.md) troubleshooting |
| Want to test on your phone | Publish (step C), then open the game in the Roblox app |
