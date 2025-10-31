# frozen_string_literal: true

require 'immutable'

# Movement squares for castling pieces, based on the color and side
module CastlingData
  DATA = Immutable.from(
    {
      %i[white kingside] => {
        king_from: Square[:e, 1],
        king_to: Square[:g, 1],
        rook_from: Square[:h, 1],
        rook_to: Square[:f, 1]
      },
      %i[white queenside] => {
        king_from: Square[:e, 1],
        king_to: Square[:c, 1],
        rook_from: Square[:a, 1],
        rook_to: Square[:d, 1]
      },
      %i[black kingside] => {
        king_from: Square[:e, 8],
        king_to: Square[:g, 8],
        rook_from: Square[:h, 8],
        rook_to: Square[:f, 8]
      },
      %i[black queenside] => {
        king_from: Square[:e, 8],
        king_to: Square[:c, 8],
        rook_from: Square[:a, 8],
        rook_to: Square[:d, 8]
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
