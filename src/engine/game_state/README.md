# `game_state/`

This folder implements the `GameState` abstraction.

- The entry point is `game_state.rb`; all other files are dependencies.

## Included Files

- `game_query.rb` – Handles all read-only queries on a given game state.
- `position.rb` - A simple data container of a snapshot of the game at a certain turn.
- `board.rb` – Provides an immutable interface to board state using a persistent array. Encapsulates piece placement, movement, and removal without mutation.
- `persistent_array.rb` – A custom immutable array-like structure used exclusively by `Board`.
- `no_legal_moves-helper` - An internal `GameQuery` helper module; provides the `#no_legal_moves?` private method.