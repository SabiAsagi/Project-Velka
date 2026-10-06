---
name: genex-tool-character
description: Generate a rigged, animated 3D character or creature with `npx genex character` and `npx genex creature`, then give it any move in plain words with `npx genex character animate`. Covers the guided concept-to-final flow, the one-shot direct path, the 8-way locomotion set, and searching the ready-made animation library. Files download to ./assets.
---

# Genex Tools · Character

A rigged humanoid body with animation clips bound to it — the player, an NPC, an
enemy. The output is a GLB with a skeleton and named clips, loadable anywhere.

For a prop, vehicle or building, use `$genex-tool-model`. For a non-humanoid
body plan (quadruped, flier, serpent) use that skill's `model rig` lane — this
one produces biped-shaped bodies.

## From the user's reference images

When the user supplies a character reference, send those images to Meshy:

```bash
npx genex character --image ./front.jpg --image ./back.jpg --texture 8k --polycount 100000 --pose t-pose --no-wait
```

`--image` is repeatable, 1-4 PNG/JPEG views of the same character, one view per
image. Local files must total at most 4 MB; Genex asset URLs also work. Split a
contact sheet into individual views first. This is one shot: it skips concept
generation and rigs the reference-derived mesh. An optional brief is only a
ledger label, not text conditioning. Do not add `--direct-text`, guided
subcommands or their approval flags. Ultra is on by default; select texture
size and face budget for the requested quality. `creature --image` uses this
same route without the player controller pack.

## The guided flow (three steps, one approval each)

Use this when creating a new look from text and a person is choosing it:

```bash
npx genex character "stylized sci-fi courier, practical layered clothing"
# → three concept candidates. SHOW them and wait for an explicit pick.

npx genex character preview <concept-id> --candidate 2 --user-approved
# → a 3D preview of that one, four views. Show it; wait for approval.

npx genex character finalize <preview-id> --user-approved --approve-remesh 10000
# → the rigged, game-ready character at that face budget.
```

Each step needs the previous step's generation id. The approval flags are not
ceremony: they record that a person actually looked and chose, and each step
costs credits.

## The knobs (Meshy 7 on every lane)

Ultra and 4k textures are the defaults; every knob is priced in the quote.
Pick per role and say so in one line:

- `--approve-remesh <faces>` (finalize) / `--polycount <faces>` (one shot):
  the rigging copy's face budget, 10000-100000 — 10000 for crowds and
  distance, 20000-30000 for a third-person player body, 50000+ only for a
  close-up hero. Moves no cost.
- `--texture 2k|4k|8k` (preview / one shot): 8k is +5 credits, for close-ups.
- `--no-ultra` (preview / one shot): −6 credits, less surface detail — stand-ins
  and crowd enemies.
- `--pose a-pose|t-pose` (one shot): the preferred rest pose.
- `--height <metres>`: 0.5-3, default 1.7.

## One shot

When nobody is choosing — a background NPC, a quick test:

```bash
npx genex character "stylized sci-fi courier" --direct-text
npx genex creature "hulking bone seraph, upright stance"
```

`creature` is the same lane with enemy defaults: no approval steps, no player
controller pack (and priced without one). Biped-shaped bodies only. The knobs
above apply: a crowd enemy is `--polycount 10000 --no-ultra --texture 2k`.

## Import a character the user already has

```bash
npx genex character import ./knight.glb --height 1.8   # free upload + Uthana auto-rig (finger joints; --no-fingers skips them)
npx genex character animate <id> --locomotion          # then the walk/run set — an import has no clips yet
```

Biped humanoid, T- or A-pose, feet on the ground, facing +Z, `.glb` ≤ 30 MB.
**Never rebuild a mesh the user gives you** — import it. The result is a
Uthana-rigged body: verbs, `--locomotion` and `--video` work; the Meshy
catalog and controller pack do not. Non-biped bodies: `npx genex model
import` + `npx genex model rig`.

The same door takes a `npx genex model` result: a humanoid mesh from the
model lane, imported here, is a rigged character without the character
lane's pose QA. If `npx genex character` reports that Meshy's rig failed
pose QA in both rest poses, the platform already did this for you — the
character lands rigged by Uthana, with no controller pack, and the terminal
says so. Animate it exactly like an import.

## Animating it

Say what the character should DO, in plain words — one clip per verb:

```bash
npx genex character animate <character-id> "overhead slam" "parry and recover"
npx genex character animate <character-id> --locomotion          # the 8-way walk + run set
npx genex character animate <character-id> "victory pose" --video ./take-3.mp4
npx genex character motions <character-id>                        # what is installed
```

- `--locomotion` — the full 8-direction walk and run set, 16 clips.
- A movement request by name: `"walk forward"` is ONE clip in the `walk.forward`
  slot, `"run"` alone is the 8-direction run set, `"strafe"` is walk left + right.
  A boss that only walks at the player needs `"walk forward"`, not the set.
- `--video <file>` — use your own footage as the reference.
- `--duration 5-8` — a longer reference video for a multi-beat move, so it lands instead of rushing. Bills per second.
- `--action <id|query>` — pick a ready-made clip from the library instead of generating.

`npx genex creature animate <id> "<verb>"` is the same lane for an enemy.

Free and spend-free: the command prints its PLAN before anything is charged —
one line per request naming its route and clip count. READ IT: a phrase that
reads as movement expands to a set, and a stance or an attack is one clip.
Show that plan to the user when the cost matters.

Derive the list from the game's states first — idle, the moves it actually
walks, each attack, hurt, defeat — and request those. A full set nobody's
controller plays is generation time and load time spent on nothing.

## When a batch does not fully land

A batch is not all-or-nothing. Clips that landed are installed and paid for;
the terminal says `N of M clips landed — missing: …` with the exact re-run
command for the missing verbs, and the credits for what did not land come
back. `--json` carries `partial: true` and the `failures` list; `wait --all`
marks the row `partial`. A verb the video model would not film is described
instead, and the batch names it — watch that clip on the character before
calling it done.

## The ready-made library

```bash
npx genex animations search "rifle reload" --limit 10
```

Free. Search by gameplay intent, then bind a result with `--action <id>`. Always
look here first — a library clip costs nothing to generate.

## Cost

Typical: **32** concept · **41** preview · **29** finalize · **64** one-shot
character · **46** creature · **18** import (Uthana auto-rig; the upload is
free) · **46 per clip** for a described move, less for a movement clip and a
little more for one filmed first · **free** for a library search
(1 credit = $0.01). `--texture 8k` adds 5, `--no-ultra`
takes 6 off. Live prices and your balance: `npx genex doctor`.

## Waiting

Character stages take SEVERAL MINUTES server-side, and so does a motion
batch — each clip is its own provider job; a 16-clip set is ten minutes or
more. Do not sit in a foreground wait: pass `--no-wait`, keep building, then
`npx genex wait --all` for one status line each and `npx genex wait <id>` to
pick one up. **Re-running a character command bills a NEW character.**

## Troubleshooting

- **A four-legged prompt came back upright** — the rig here is biped-shaped only. Generate the body with `npx genex model` and rig it with `npx genex model rig --type quadruped` (see `$genex-tool-model`), or ship it static and animate in code.
- **"Rigged by Uthana instead" on a `character` / `creature` result** — Meshy's rig failed pose QA in both rest poses (armored and heavily clothed bodies do), so the platform auto-rigged the mesh. Nothing to redo: give it moves with `npx genex character animate <id> --locomotion` and plain-word verbs; the Meshy catalog does not apply.
- **`character animate` says the character is still generating** — wait for it first (`npx genex wait <id>`); the animate door only opens on a finished rig.
- **Rigs rest facing +Z.** Set yaw explicitly when you place one, and never mirror a skinned mesh with a negative scale — it inverts the whole thing silently.
- **Out of credits** — the error prints balance, price and refill date. Relay it; don't retry.
- **Anything else** — `npx genex doctor`.
