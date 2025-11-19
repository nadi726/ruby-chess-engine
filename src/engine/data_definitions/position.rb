# frozen_string_literal: true

require_relative 'board'
require_relative 'primitives/colors'
require_relative 'components/castling_rights'

# Immutable container for all the data about the current chess position:
# board layout, active color, en passant target, castling rights, and halfmove clock.
Position = Data.define(
  :board,
  :current_color,
  :en_passant_target,
  :castling_rights,
  :halfmove_clock
) do
  def self.start
    Position[
      board: Board.start,
      current_color: :white,
      en_passant_target: nil,
      castling_rights: CastlingRights.start,
      halfmove_clock: 0
    ]
  end

  # An identifier for indicating whether positions are identical in the context of position repetitions,
  # as used for threefold/fivefold repetition detection.
  def signature
    [
      board,
      current_color,
      en_passant_target,
      castling_rights
    ].hash
  end

  def other_color
    flip_color(current_color)
  end
end
