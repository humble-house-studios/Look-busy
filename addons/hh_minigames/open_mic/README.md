# open_mic — the open mic

Five picks from your material, 100 laughs to land the set. A Setup doubles
the next Punchline; Tags after a Punchline land at x1.5. Coworker secrets
become killer bits, the founder's memo gives BIG DEAL.

- Entry: `main.tscn` (`open_mic.gd`). Rules: `final_set.gd` (class `FinalSet`).
- `finished`: once per set. `score` = laughs.
- Host calls: `crew.secrets`, `state.is_done("memo")`, `stage_won()`.
- Tests: `tests/test_open_mic.gd`.
