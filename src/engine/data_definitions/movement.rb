# frozen_string_literal: true

require 'ice_nine'
require 'ice_nine/core_ext/object'

# Describes the movement pattern of a piece.
# Does not account for special moves.
# A single element consists of:
# - deltas: movement offsets in [file_delta, rank_delta] format (x -> file, y -> rank)
# - repeat: a boolean indicating whether or not the piece can move until it encounters another piece.

straight = [[0, 1], [0, -1], [1, 0], [-1, 0]]
diagonal = [[1, 1], [-1, 1], [1, -1], [-1, -1]]
knight = [
  [2, 1], [1, 2], [-1, 2], [-2, 1],
  [2, -1], [1, -2], [-1, -2], [-2, -1]
]

MOVEMENT = {
  king: { deltas: straight + diagonal, repeat: false },
  queen: { deltas: straight + diagonal, repeat: true },
  rook: { deltas: straight, repeat: true },
  bishop: { deltas: diagonal, repeat: true },
  knight: { deltas: knight, repeat: false },
  pawn: { deltas: [[0, 1]], repeat: false } # simplified
}.deep_freeze
