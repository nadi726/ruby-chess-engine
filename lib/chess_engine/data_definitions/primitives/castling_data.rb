# frozen_string_literal: true

require 'immutable'
require_relative '../square'

module ChessEngine
  # Movement squares for castling pieces, based on the color and side
  module CastlingData
    SIDES = %i[kingside queenside].freeze

    FILES = Immutable.from(
      {
        kingside: {
          king_to: :g,
          rook_from: :h,
          rook_to: :f,
          king_path: %i[e f g],
          intermediate_squares: %i[f g]
        },
        queenside: {
          king_to: :c,
          rook_from: :a,
          rook_to: :d,
          king_path: %i[e d c],
          intermediate_squares: %i[b c d]
        }
      }
    ).freeze

    RANK_FOR_COLOR = { white: 1, black: 8 }.freeze

    def self.rank(color)
      RANK_FOR_COLOR.fetch(color)
    end

    def self.king_from(color, _side = nil)
      Square[:e, rank(color)]
    end

    def self.king_to(color, side)
      Square[FILES.fetch(side)[:king_to], rank(color)]
    end

    def self.king_path(color, side)
      FILES.fetch(side)[:king_path].map { |f| Square[f, rank(color)] }
    end

    def self.rook_from(color, side)
      Square[FILES.fetch(side)[:rook_from], rank(color)]
    end

    def self.rook_to(color, side)
      Square[FILES.fetch(side)[:rook_to], rank(color)]
    end

    # Every square passed through either by the king or the rook, not including starting squares
    def self.intermediate_squares(color, side)
      FILES.fetch(side)[:intermediate_squares].map { |f| Square[f, rank(color)] }
    end
  end
end
