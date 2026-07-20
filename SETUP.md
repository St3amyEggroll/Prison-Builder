# 🎮 Setup — from zero to playing Lockdown

No coding anywhere in this guide. Total time: about 15 minutes the first time, 2 minutes for every update after that.

## 1. One-time: install Roblox Studio

1. If you don't have a Roblox account: go to [roblox.com](https://www.roblox.com) → **Sign Up**.
2. Go to [create.roblox.com](https://create.roblox.com) → click **Start Creating** → download and install **Roblox Studio** → log in with your account.

## 2. Download the game file

1. On this repo's GitHub page, click **`Lockdown.rbxlx`** in the file list.
2. Click the **Download raw file** button (the down-arrow icon at the top-right of the file view).
3. It lands in your Downloads folder.

## 3. Open it and play

1. Double-click the downloaded `Lockdown.rbxlx` — it opens in Roblox Studio. (If double-clicking doesn't work: open Studio → **File → Open from File** → pick it.)
2. Press the big ▶ **Play** button in the Home tab (or press **F5**).
3. You spawn on a plaza — the row of prisons is right in front of you, and one has **your name over the gate**. Walk to it with **W A S D** (hold right mouse button and move the mouse to look around; **Space** jumps).
4. Walk through the gate and step on the **glowing green pad**. 💥 Cell #1 builds itself and Sneaky Pete moves in — he pays you $2/sec for the privilege.
5. Watch the cash counter climb. When you can afford it, step on the pad again for cell #2. That's the Phase 1 loop!
6. The red **Stop** button (Shift+F5) ends the play test.

## 4. One-time: make saving work (~2 minutes)

Your cash and cells save to Roblox's servers — but only after the game is published:

1. **File → Publish to Roblox As...** → name it `Lockdown` → **Create**.
2. Home tab → **Game Settings** → **Security** → switch **Enable Studio Access to API Services** to ON → **Save**.
3. Done. From now on, progress survives between sessions. (Before this step the game still plays fine — it just starts fresh each time, and you may see a harmless DataStore warning in the Output window.)

## 5. Play with a friend

1. Publish first (step 4).
2. **File → Game Settings → Permissions** → set the game to **Friends** (or **Public**) → **Save**.
3. On [roblox.com](https://www.roblox.com): your profile → **Creations** → **Lockdown** → **Play**. Your friend finds it the same way (you must be Roblox friends if you picked Friends).
4. Everyone who joins gets their **own** prison plot — up to 6 per server in this build.

## 6. When Claude ships an update

1. Re-download the new `Lockdown.rbxlx` (step 2 again).
2. Open it in Studio → **File → Publish to Roblox As...** → ⚠️ **select your EXISTING Lockdown game** instead of creating a new one. That's what keeps everyone's saved progress.

## What's in this build (Phase 1 MVP)

- Your own prison plot with walls, a gate, and your name on the sign
- The green buy pad: step on it → cell builds → an inmate moves in
- 22 buyable cells with rising prices; each inmate pays $2/sec
- Silly named inmates (lightweight custom rigs — no phone lag) with idle sway
- Cash HUD with smooth count-up, floating `+$` popups, sounds
- Cloud saving of your cash and cells (after step 4)
- Up to 6 players, each with their own plot, in one server

## Troubleshooting

| Problem | Fix |
|---|---|
| "My money resets every time" | Do step 4 (publish + API access) |
| Orange DataStore warning in Output | Same cause — harmless until you publish |
| I fell off the world / got stuck | Press Esc → R → Enter to respawn |
| Want to test on your phone | Publish (step 4), then open the game in the Roblox app on your phone |
