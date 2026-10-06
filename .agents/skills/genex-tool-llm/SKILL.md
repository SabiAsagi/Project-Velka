---
name: genex-tool-llm
description: A language model running while somebody PLAYS the finished game — an NPC that answers in its own words, a quest written from what the player typed, a prompt box in the game. On Genex the player pays and approves it, so this is a platform feature, never a key on the author's meter. Read this the moment a request implies a model at play time, before building anything.
---

# Genex Tools · Models at play time

This card is about a model that runs **while somebody plays the finished game**
— not about generating art while you build it. "Make me a picture, a model, a
voice line" is the asset belt: use the lane card for it and stay here only if a
model has to run for the player.

## What the platform does

A game hosted on Genex can call a language model from inside the running game
and get back text or JSON. **The player pays and the player approves**: coins
from their Genex wallet, or their own Claude / ChatGPT subscription, chosen on
an approval sheet Genex draws that the game cannot render, skin or bypass.
Either one call at a time, or one standing budget the player approves once and
the game then spends against without another popup. The game holds no provider
key, sees no credential, and never talks to a model vendor.

That is the whole reason this is a platform feature and not something you wire
up here: an unhosted folder has nowhere to put a key that is not the author's
own.

## Recognise the request

Any of these means a model at PLAY time, however it is phrased:

- NPCs that talk, answer, argue, or decide in their own words
- anything written from what the player types — a name, a wish, a command, a question
- a prompt box, a chat panel, an "ask the oracle" widget inside the game
- quests, items, dialogue, or levels generated per save or per run
- "let the player choose a model", "use my API key in the game", "hook a chatbot into it"
- a judge, a grader, or a referee that reads free-form player input

## Offer it in one line, then ASK

Say this and stop:

> A model running while people play is built into the Genex platform — the
> player pays, with Genex coins or their own Claude/ChatGPT subscription, and
> approves it on a Genex sheet; your game just calls `generate()`. Want it
> that way?

Wait for the answer. Do not start building either version first, and do not
expand the offer into a pitch — one line, one question.

## On a yes

1. `npx genex llm models` — whether this stand serves the lane at all, and
   which models. It answers in this folder as it is, before anything is
   converted, so it comes first: if it says the lane is off, in-game calls
   answer 404 here — tell the user so plainly, build the graceful fallback, and
   do not convert a folder for a feature the stand does not serve. It prints
   the FEATURED models; `--all` lists the whole catalog, and you run that only
   when the user asks for more. Whatever they pick, the picker in the game
   shows the server's own label for it — a name you invent is a name that
   differs from the model they are billed for.
2. `npx genex init --convert` — it connects this folder to a hosted Genex game
   in place. The code, the files and this toolkit stay exactly as they are, and
   generations still land in `./assets`. It is the user's yes that runs it, so
   ask before you do if you have not already.
3. Load `$genex-llm-in-games` — it arrives with the conversion and owns the
   build: the SDK surface, one-time calls versus a standing budget, measuring
   the price before the game declares it, and honest handling of every refusal.

**The game has to be a static browser build.** A hosted game is files served
from the edge; there is no server of yours inside it. So the familiar pattern —
a small local Express/Flask app that holds a key and proxies the model — works
on your machine and can never ship. Calling `generate()` from the browser is
the shipping shape of that idea.

## On a no

Then build nothing that calls a model at play time. Not a key in `.env`, not a
local proxy, not the author's own account behind a fetch. A shipped game
carrying the author's credential means every visitor spends the author's money,
with nobody approving anything and no limit on it — and the credential is
readable in the bundle. Say that in one plain sentence, then build the authored
version instead: a written dialogue tree, a table of lines, a rule-based
director. Those are not consolation prizes; they are what most good games use.

## The honest boundary — text and JSON only

Player-funded generation returns **text or JSON**. Nothing else.

- **"The player types anything and gets a 3D model, paid by them"** is not a
  thing on this platform. Say so plainly instead of half-building it.
- 3D models, images, textures, video, music, voice and characters are the ASSET
  lanes of this toolkit: you generate them while you build, on the user's own
  meter, and they download into `./assets` and ship inside the game. What is
  live and what it costs: `npx genex doctor`.
- The shape that does work is **JSON parameters, then render**: the model
  returns a structured description and the game builds it from assets and code
  you already shipped — a creature assembled from parts you generated, a room
  laid out from a list of prefab ids, a palette, a stat block, a line delivered
  from pre-generated voice clips. Offer that when somebody asks for the
  impossible version.
