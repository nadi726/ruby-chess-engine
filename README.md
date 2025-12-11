# Ruby Chess Engine
A modular, deterministic chess engine built around immutable objects.
Cleanly expresses chess concepts in code and designed for easy integration with any UI.

> ⚠️ Note: This is not a competitive chess engine like [Stockfish](https://stockfishchess.org/).
While AI features could be added in the future, the core purpose of this project is to provide a ruby gem for cleanly representing chess in code.

# Features
- UI-agnostic design
- Fully immutable game state representation
- Modular: components can be used separately or coordinated via the `Engine` class
- Chess concepts map cleanly to code: squares, pieces, board, rules, etc
- Pluggable notation systems for both parsing and formatting: a custom notation called ERAN is the default,
  but parsers & formatters for any other notation system(SAN, LAN, etc) can be implemented and plugged in instead
- FEN import and export

# Examples
### Simple usage
```ruby
require 'chess_engine_rb'

engine = ChessEngine::Engine.new
engine.new_game
engine.play_turn('P e2-e4') # play a move
puts engine.status.board # prints the board
puts engine.to_fen # prints FEN
engine.from_fen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1') # Load from FEN
```

### Using a listener
```ruby
require 'chess_engine_rb'

class Listener
  FORMATTER = ChessEngine::Formatters::ERANShortFormatter

  def on_game_update(update)
    if update.failure?
      puts "Update failed: #{update.error}"
    elsif update.game_ended?
      puts "Game over! Reason: #{update.endgame_status.cause}"
    elsif update.offered_draw
      puts 'Draw has been offered'
    else
      puts "Move accepted: #{FORMATTER.call(update.event)}"
    end
  end
end

engine = ChessEngine::Engine.new
engine.add_listener(Listener.new)
engine.play_turn('P e7-e6') # => Move accepted: P e7-e6
engine.play_turn('HA!') # => Update failed: invalid_notation
engine.offer_draw # => Draw has been offered
engine.resign # => Game over! Reason: resignation
```

For more complete examples, see the examples folder.

# Installation
## From RubyGems (recommended)
- Install Ruby (version >= 3.4.1) if you haven't already (on Windows, you can use [RubyInstaller](https://rubyinstaller.org/downloads/))
- Install the gem: `gem install chess_engine_rb`
- If you want to see the engine in action, download the example CLI `examples/chess_cli.rb`  and run it: `ruby chess_cli.rb`

## From source
- Make sure Ruby (version >= 3.4.1) and Bundler are installed
- Clone the repository and run `bundle install` from the project's root directory

# More information
- See the [architectural overview](docs/architecture.md)
- Browse the docs and examples for more information

# Possible future additions
- Move undo
- SAN and LAN parsers/formatters
- PGN import/export
- Support for chess variants
- Performance improvements
- Comprehensive perft testing
- Basic AI

# License
This project is licensed under the [MIT License](LICENSE).
