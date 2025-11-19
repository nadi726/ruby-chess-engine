# `game_state/`

This folder implements the `GameState` abstraction.

- The entry point is `game_state.rb`; all other files are dependencies.

## Included Files

- `game_query.rb` – Handles all read-only queries on a given game state.
- `game_history.rb` - Represents the game's history from the point a `GameState` was first initialized onwards.
- `legal_moves_helper` - An internal `GameQuery` helper module; provides the `#legal_moves` private method.