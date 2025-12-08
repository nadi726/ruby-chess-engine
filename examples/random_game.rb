#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'chess_engine_rb'

# Random Game Simulator
# Plays a full game by selecting legal moves at random until the game ends.
#
# Usage:
#   ruby examples/random_game.rb [FEN]
# Example:
#   ruby examples/random_game.rb
#   ruby examples/random_game.rb "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

def play_random_game(engine, formatter = ChessEngine::Formatters::ERANLongFormatter)
  move_count = 0

  until engine.status.game_ended?
    state = engine.status.state
    legal_moves = state.query.legal_moves.to_a
    break if legal_moves.none?

    move = legal_moves.sample
    engine.play_turn(move)
    move_count += 1

    puts "Move #{move_count}: #{formatter.call(move) || move}"
  end

  outcome = engine.status.endgame_status
  if outcome.winner
    puts "Game over! #{outcome.winner} wins by #{outcome.cause}."
  else
    puts "Game over! Draw by #{outcome.cause}."
  end
end

def run_random_game(fen = nil)
  engine = ChessEngine::Engine.new(default_parser: ChessEngine::Parsers::IdentityParser)
  if fen
    engine.from_fen(fen)
  else
    engine.new_game
  end

  puts "Starting random game from: #{fen || 'starting position'}"
  puts '-----------------------------------------'

  play_random_game(engine)
end

fen = ARGV[0]
run_random_game(fen)
