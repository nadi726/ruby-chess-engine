# frozen_string_literal: true

require 'immutable'

# Movement positions for castling pieces, based on the color and side
CASTLING_DATA = Immutable.from(
  {
    %i[white kingside] => {
      king_from: Position[:e1],
      king_to: Position[:g1],
      rook_from: Position[:h1],
      rook_to: Position[:f1]
    },
    %i[white queenside] => {
      king_from: Position[:e1],
      king_to: Position[:c1],
      rook_from: Position[:a1],
      rook_to: Position[:d1]
    },
    %i[black kingside] => {
      king_from: Position[:e8],
      king_to: Position[:g8],
      rook_from: Position[:h8],
      rook_to: Position[:f8]
    },
    %i[black queenside] => {
      king_from: Position[:e8],
      king_to: Position[:c8],
      rook_from: Position[:a8],
      rook_to: Position[:d8]
    }
  }
)
