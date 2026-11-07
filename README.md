# Look Busy

A PS1-style 3D office where every desk runs a real game. You just joined
Humble House Games: walk the floors, sit down at a computer, play, and don't
get caught by the boss. Built in Godot 4.3.

**Play the latest build:** https://humble-house-studios.github.io/look-busy/

Hold your phone upright for the mobile layout; turn it sideways for the Steam
layout. Keyboard + mouse, touch and an Xbox controller all work. Every push to
`main` rebuilds that link (`.github/workflows/deploy.yml`). Project rules are in
`CLAUDE.md`.

## Mini games
All the mini games (the stand-up game, claw machine, coin pusher, Fall Guy,
Rage Cage, trading floor, desk golf, the pitch, the open mic) live in
`addons/hh_minigames/`. **This repo is their source of truth**: changes there
are copied to [killin-in-comedy](https://github.com/humble-house-studios/killin-in-comedy)
by a pull request (`.github/workflows/sync-minigames.yml`). See
`addons/hh_minigames/README.md` for the shared interface.

Phone Pong, Proof Hand, Cube Desk and the Loot Machine come from their own
repos at build time: `tools/fetch_games.sh` (run it before playing the office
locally).

## Tests
GUT tests for the office (`tests/`) and every mini game
(`addons/hh_minigames/*/tests/`) run on every push before the web build:

    godot --headless -s addons/gut/gut_cmdln.gd

History: this repo was split out of killin-in-comedy with its full git history.
