# 🧱 Building the map & assets (your department!)

The code never generates the world anymore — **you build everything in Studio**, and the systems find your work through two magic folders:

| Folder | Where | What goes in it |
|---|---|---|
| `PlotZones` | inside **Workspace** | Flat **Parts** — each one is a player's build area |
| `Buildables` | inside **ReplicatedStorage** | **Models** — every one appears in the build menu automatically |

That's the whole contract. No code edits, no naming lists, nothing to register.

---

## 🗺️ Making the map

1. Build whatever you want in Workspace — terrain, roads, mountains, the works. It's all yours.
2. In the Explorer, hover **Workspace** → click the **+** → add a **Folder** → rename it exactly `PlotZones`.
3. Add flat **Part**s inside that folder — one per player who can build (4–6 is a good start). For each part:
   - Make it big (something like **128 × 1 × 128** studs) and flat.
   - **Anchor it** (Properties → Anchored ✓). Very important — unanchored zones fall through the world!
   - Any position and any rotation is fine; the build grid adapts to each zone automatically.
   - Keep the space **above** it clear — that's where players build.
   - **The Part's +Z side is the plot's FRONT** — handcuffed new prisoners appear there waiting for intake. Rotate the Part so its front faces your road/entrance. (Quick check: in Studio, select the Part and press Play — arrivals gather on the front side.)
4. Add a **SpawnLocation** (Home tab → Part dropdown, or search the toolbox) wherever players should first appear. When a player claims a zone, they're automatically walked to its edge.

> **No PlotZones folder yet?** The game builds a simple flat test map by itself so it always runs. The moment your folder exists with at least one Part, your map takes over completely.

## 🧩 Making a buildable asset

1. Build the thing out of parts anywhere in Workspace (a wall, a fancy cell, a snack machine…).
2. **Anchor every part** (select all parts → Properties → Anchored ✓). The placement system doesn't weld anything — unanchored parts will rain from the sky.
3. Select all its parts → **right-click → Group as Model** (Ctrl+G).
4. Rename the Model to the name players should see (e.g. `Stone Wall`).
5. In the Explorer, make sure **ReplicatedStorage** has a folder named `Buildables` (create it the same way as step 2 above if not) — then **drag your Model into it**.
6. Press Play — it's in the build menu, 3D thumbnail and all. Done.

**Size & snapping:** everything snaps to a 4-stud grid. A model up to 4 studs wide takes 1 square; up to 8 studs takes 2; and so on. Don't stress about exact sizes — the system measures your model and rounds up.

**Optional powers** (set via the Model's *Attributes* section at the bottom of the Properties panel → click **+ Add Attribute**):

| Attribute | Type | What it does |
|---|---|---|
| `SpawnsInmate` | boolean, ticked | Marks the asset as **housing for one prisoner**. Prisoners arrive via the 🚔 Intake menu, wait handcuffed at your gate, and get escorted into an empty one of these. Put it on cell-type assets. |
| `Price` | number | *Coming with the economy phase* — what it'll cost to place. Safe to add now. |

**Sizing conventions worth copying from the placeholders:** the Wall fills a *whole* 4-stud grid square (so wall runs tile solid, Prison Architect style), and the Fence/Security Door are thin panels spanning the full 4-stud width (so doors drop cleanly into fence lines). Matching those shapes keeps your assets mixing well with drag-to-build.

## 🔄 Replacing the placeholders

The menu starts with 6 placeholder assets I made (Wall, Floor Tile, Fence, Security Door, Prison Cell, Guard Tower) so the system is testable before your art exists. They politely get out of your way:

- Name your model **the same** as a placeholder (e.g. `Wall`) → yours is used, mine never appears.
- Want them ALL gone? Select the `Buildables` folder → Attributes → add `NoPlaceholders` (boolean) → tick it.

## 🧪 Testing your stuff

1. In PowerShell, in the project folder: `rojo serve`
2. In Studio (with **your** place open): **Plugins tab → Rojo → Connect** — the game code streams in.
3. Press ▶ Play. Build menu → place things on your zone.
4. Stop, tweak your models, Play again. New assets show up next Play; **assets added while already playing need a restart of Play mode.**
5. Save your place (Ctrl+S). The synced code stays in the file — you only reconnect Rojo when Claude ships a code update.

## 🚑 Troubleshooting

| Problem | Cause |
|---|---|
| My model isn't in the menu | It's not a **Model** (group it, Ctrl+G), it's not directly inside `Buildables`, or you added it mid-Play — restart Play mode |
| It floats above the ground / sinks into it | A stray invisible or far-away part is inflating the model's bounding box — check inside the model for parts you forgot to delete |
| It takes up way more grid squares than it should | Same cause as floating — the bounding box is measured around *everything* in the model |
| Ghost preview is red | Overlapping something already placed, or you're outside your zone |
| Placed it and parts fell/flew away | Unanchored parts — anchor everything in the model |
