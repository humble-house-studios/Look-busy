# pitch — the boardroom pitch

Match each board member's objection with the right answer to get greenlit
("YES, AND" matches anything, one redraw).

- Entry: `main.tscn` (`pitch_screen.gd`). Rules: `pitch.gd` (class `Pitch`).
- `finished`: once per pitch. `score` 1 greenlit / 0 passed.
- Host calls: `state.has("theo_vote")`, `state.has("hr_badge")`, `pitch_won()`.
- Tests: `tests/test_pitch.gd`.
