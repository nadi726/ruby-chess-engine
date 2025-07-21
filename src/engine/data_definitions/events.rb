# frozen_string_literal: true

# Events represent game actions or state changes.
# They are produced by the parser (user intent) and by the engine (execution outcome).
# Each event is self-contained and immutable after creation.

########## Action Events (can trigger rule processing)

# Move a piece from one square to another.
# Optionally includes the moving piece (usually added by engine).
MovePieceEvent = Data.define(:from, :to, :piece) do
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
# Captured position is derived, not stored directly.
EnPassantEvent = Data.define(:from, :to) do
  def captured_position
    Position.new(to.file, from.rank)
  end
end

# Promotion request: promote piece at to `new_piece`.
PromotePieceEvent = Data.define(:piece_type)

########## State Events (supporting metadata or consequences)

# Piece removal — e.g., for captures.
# Either position or piece (or both) can be specified.
RemovePieceEvent = Data.define(:position, :piece) do
  def initialize(position: nil, piece: nil)
    super
  end
end

# A player is in check.
CheckEvent = Data.define(:color)

# A player is checkmated.
CheckmateEvent = Data.define(:color)

# Game is drawn for a given reason (e.g., stalemate, repetition).
DrawEvent = Data.define(:reason)
