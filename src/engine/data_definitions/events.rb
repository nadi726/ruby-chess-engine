# frozen_string_literal: true

require 'immutable'
require_relative 'castling_data'

# Events represent game actions or state changes.
# They are produced by the parser (user intent) and by the engine (execution outcome).
# Each event is self-contained and immutable after creation.
class GameEvent < Data
end

# ActionEvents are the "main" events, in the sense that they determine how the event list is acted upon
# Every event sequence should have exactly one ActionEvent
class ActionEvent < GameEvent
end

# StateEvents provide extra metadata or inform of consequences that give additonal context to the event sequence
# For example, RemovePieceEvent is about crucial information that changes the board,
# while CheckmateEvent mostly just informs the player about a checkmate.
class StateEvent < GameEvent
end

########## Action Events (inherit ActionEvent)

# Move a piece from one square to another.
# Optionally includes the moving piece (usually added by engine).
MovePieceEvent = ActionEvent.define(:from, :to, :piece) do
  def initialize(from:, to:, piece: nil)
    super
  end
end

# Castling move.
# 'side' is one of: :kingside, :queenside
CASTLING_SQUARES = Immutable.from(
  {
    %i[white kingside] => [Position[:g1], Position[:h1], Position[:f1]],
    %i[white queenside] => [Position[:c1], Position[:a1], Position[:d1]],
    %i[black kingside] => [Position[:g8], Position[:h8], Position[:f8]],
    %i[black queenside] => [Position[:c8], Position[:a8], Position[:d8]]
  }
)

CastlingEvent = ActionEvent.define(:side, :color) do
  def king_from
    CASTLING_DATA[[color, side]][:king_from]
  end

  def king_to
    CASTLING_DATA[[color, side]][:king_to]
  end

  def rook_from
    CASTLING_DATA[[color, side]][:rook_from]
  end

  def rook_to
    CASTLING_DATA[[color, side]][:rook_to]
  end
end

# En passant move (special pawn capture).
EnPassantEvent = ActionEvent.define(:from, :to) do
  def captured_position
    Position.new(to.file, from.rank)
  end
end

########## State Events (inherit StateEvent)
# Promote piece to `piece_type`.
PromotePieceEvent = StateEvent.define(:piece_type)

# Piece removal — e.g., for captures.
# Either position or piece (or both) can be specified.
RemovePieceEvent = StateEvent.define(:position, :piece) do
  def initialize(position: nil, piece: nil)
    super
  end
end

# A player is in check.
CheckEvent = StateEvent.define(:color)

# A player is checkmated.
CheckmateEvent = StateEvent.define(:color)

# Game is drawn for a given reason (e.g., stalemate, repetition).
DrawEvent = StateEvent.define(:reason)
