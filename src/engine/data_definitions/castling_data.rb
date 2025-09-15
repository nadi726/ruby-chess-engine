# frozen_string_literal: true

require 'immutable'

# Movement positions for castling pieces, based on the color and side
module CastlingData
  DATA = Immutable.from(
    {
      %i[white kingside] => {
        king_from: Position[:e, 1],
        king_to: Position[:g, 1],
        rook_from: Position[:h, 1],
        rook_to: Position[:f, 1]
      },
      %i[white queenside] => {
        king_from: Position[:e, 1],
        king_to: Position[:c, 1],
        rook_from: Position[:a, 1],
        rook_to: Position[:d, 1]
      },
      %i[black kingside] => {
        king_from: Position[:e, 8],
        king_to: Position[:g, 8],
        rook_from: Position[:h, 8],
        rook_to: Position[:f, 8]
      },
      %i[black queenside] => {
        king_from: Position[:e, 8],
        king_to: Position[:c, 8],
        rook_from: Position[:a, 8],
        rook_to: Position[:d, 8]
      }
    }
  )

  def self.lookup(color, side)
    DATA.fetch(Immutable.from([color, side]))
  end

  def self.[](color, side)
    lookup(color, side)
  end

  def self.king_from(color, side)
    lookup(color, side)[:king_from]
  end

  def self.king_to(color, side)
    lookup(color, side)[:king_to]
  end

  def self.rook_from(color, side)
    lookup(color, side)[:rook_from]
  end

  def self.rook_to(color, side)
    lookup(color, side)[:rook_to]
  end
end
