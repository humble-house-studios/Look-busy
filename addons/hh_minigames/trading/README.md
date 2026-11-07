# trading — the trading floor

A trading week: a goal every day (+8% Monday up to +20% Friday), the bell
closes every trade, an after-hours shop sells perks, stocks have
personalities, rumors count down to news (a quarter are fake), HOT HAND.

- Entry: `main.tscn` (`trading.gd`). Rules: `market.gd` (class `Market`).
- `finished`: at every closing bell. `score` = the day's profit; `outcome`
  "win" if the day was cleared or saved; extras `cleared`, `won` (Friday cleared).
- Host calls: `state.market_start()`, `state.has("insider_tip")`,
  `state.trading_record()`, `add_stress()`, `market_won()`.
- Balance: `godot --headless -s res://addons/hh_minigames/trading/tools/market_tune.gd`.
- Tests: `tests/test_market.gd`.
