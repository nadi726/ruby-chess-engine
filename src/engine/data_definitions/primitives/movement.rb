# frozen_string_literal: true

require 'immutable'

# Describes the movement pattern of a piece.
# Does not account for special moves.
# Each entry consists of:
# - moves: movement deltas in [file_delta, rank_delta] format (x -> file, y -> rank)
# - repeat: a boolean indicating whether the piece can move repeatedly in a direction
# For pawns (and optionally other pieces in variants), additional keys may be present:
# - attacks: movement deltas for capturing (e.g., pawn diagonal captures)
# - special_moves: an array of special move definitions.
#   Each special move is a hash with:
#     - path: an array of deltas (each [file_delta, rank_delta]) describing the move sequence
#     - condition: a lambda that takes the piece and returns true if the move is allowed
#         (e.g., only on the pawn's first move)

straight = [[0, 1], [0, -1], [1, 0], [-1, 0]]
diagonal = [[1, 1], [-1, 1], [1, -1], [-1, -1]]
knight = [
  [2, 1], [1, 2], [-1, 2], [-2, 1],
  [2, -1], [1, -2], [-1, -2], [-2, -1]
]

MOVEMENT = Immutable.from(
  {
    king: { moves: straight + diagonal, repeat: false },
    queen: { moves: straight + diagonal, repeat: true },
    rook: { moves: straight, repeat: true },
    bishop: { moves: diagonal, repeat: true },
    knight: { moves: knight, repeat: false },
    pawn: {
      moves: [[0, 1]],
      attacks: [[1, 1], [-1, 1]],
      repeat: false,
      special_moves: [
        {
          path: [[0, 1], [0, 2]],
          condition: lambda { |piece, square|
            (piece.color == :white && square.rank == 2) ||
              (piece.color == :black && square.rank == 7)
          }
        }
      ]
    }
  }
)
