#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'chess_engine_rb'

# Simple perft test for verifying engine correctness.
# This test expands all legal moves to a given depth and counts resulting positions.
# Keep in mind that the engine is very inefficient, meaning any real testing will take a lot of time.
#
#
# Usage:
#   ruby examples/perft.rb [DEPTH] [FEN]
# Example:
#   ruby examples/perft.rb 3
#   ruby examples/perft.rb 4 "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
#

def perft(start_state, depth)
  return 1 if depth.zero?

  total = 0
  stack = [[start_state, depth]]

  until stack.empty?
    state, d = stack.pop

    moves = state.query.legal_moves

    if d == 1
      total += moves.to_a.length
    else
      moves.each do |move|
        next_state = state.apply_event(move)
        stack << [next_state, d - 1]
      end
    end
  end

  total
end

def run_perft(depth, fen = nil)
  # We use `Game::State` directly in order to skip the intermediate layers unnecessary for testing
  state =
    if fen
      ChessEngine::Game::State.from_fen(fen)
    else
      ChessEngine::Game::State.start
    end

  puts "Running perft to depth #{depth}..."
  puts "Position: #{fen || 'Starting position'}"
  puts '------------------------------------'

  nodes = perft(state, depth)

  puts "Nodes: #{nodes}"
end

depth = ARGV[0] ? ARGV[0].to_i : 3
fen   = ARGV[1]

run_perft(depth, fen)
