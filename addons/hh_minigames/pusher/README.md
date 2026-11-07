# pusher — PUSH YOUR LUCK

A coin pusher: 1 token = 5 coins, a lit BONUS zone on the chute rail (shower,
mega push, token chip, gold coin), one-shove streaks x2/x3.

- Entry: `main.tscn` (cage on its own). Hosts: `pusher.gd` + `start({"host", "cage"})`.
- `finished`: on every payout. `score` = tickets; extra `jackpot`.
- Numbers: `_shared/arcade_rules.gd` (`PUSHER_*`).
