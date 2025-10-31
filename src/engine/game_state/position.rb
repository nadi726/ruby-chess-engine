# frozen_string_literal: true

require_relative 'board'

# Tracks whether each side still retains castling rights.
# Rights may be lost due to moving the king or rook, or other game events.

CastlingSide = Data.define(:kingside, :queenside) do
  def self.none
    new(false, false)
  end
end
CastlingRights = Data.define(
  :white, :black
) do
  def self.start
    CastlingRights[
      CastlingSide[true, true],
      CastlingSide[true, true]
    ]
  end

  def self.none
    new(
      CastlingSide.none,
      CastlingSide.none
    )
  end

  def get_side(color)
    color == :white ? white : black
  end
end

# Immutable container for all the data about the current chess position:
# board layout, active color, en passant target, castling rights, and halfmove clock.
# Used by `GameState` as the core snapshot of the position.
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
    current_color == :white ? :black : :white
  end
end
