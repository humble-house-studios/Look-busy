# rage_cage — RAGE CAGE

A glass smash room: a CRT, printer or coffee maker on a desk, 3 swings a play
(lock the aim, time the power). Real Voronoi fracture (`fracture.gd`, plain
plane maths): pieces off the desk pay, CLEAN DESK beats it.

- Entry: `main.tscn` (cage on its own). Hosts: `rage.gd` + `start({"host", "cage"})`.
  A play costs a token or one STRESS (`host.pay_rage()`). Saved under id `rage`.
- `finished`: once per play. `score` = tickets; extras `pieces`, `clean`.
- Numbers: `_shared/arcade_rules.gd` (`RAGE_*`); capped at 90 bodies for phones.
- Tests: `tests/test_fracture.gd`. Debug: `RAGE_DEBUG=1` prints each swing.
