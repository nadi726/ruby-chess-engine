# frozen_string_literal: true

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
# Do not use #new directly.
# 'side' is one of: :kingside, :queenside
# Use `CastleEvent.request(side)` for parser-side creation,
# and `CastleEvent.resolve(...)` for engine-side execution with positions.
CastleEvent = Data.define(:side, :king_to, :rook_from, :rook_to) do
  def self.request(side)
    new(side, nil, nil, nil)
  end

  def self.resolve(side, king_to, rook_from, rook_to)
    new(side, king_to, rook_from, rook_to)
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
