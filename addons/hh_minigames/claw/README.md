# claw — CLAW KING

A real claw machine in a glass cage: kinematic prongs, prizes held by contact,
PLAY then a 15 s steer clock, a BONUS prize (x2), mystery capsules, DOUBLE
GRAB, streaks and SO CLOSE near-misses.

- Entry: `main.tscn` (the cage on its own, `_shared/cage_stand.gd`). Hosts with
  their own cabinet use `claw.gd` with `start({"host": …, "cage": …})`.
- `finished`: once per drop. `score` = tickets won that drop.
- Numbers: `_shared/arcade_rules.gd` (`CLAW_*`).
