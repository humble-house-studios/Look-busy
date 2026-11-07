# fall_guy — FALL GUY

A ragdoll on a trampoline in a floor-to-ceiling glass column: BOUNCE as he
lands, lean into the bumpers, ring the bell. PERFECT chains, a lit TARGET bumper.

- Entry: `main.tscn` (cage on its own). Hosts: `ragdoll.gd` + `start({"host", "cage"})`.
  The office saves its bests under the id `ragdoll`.
- `finished`: once per landing. `score` = tickets; extras `points`, `beaten`.
- Numbers: `_shared/arcade_rules.gd` (`RAGDOLL_*`).
