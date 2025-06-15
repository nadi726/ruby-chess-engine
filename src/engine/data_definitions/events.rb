# frozen_string_literal: true

# Events represent game actions or state changes.
# They are produced by the parser (user intent) and by the engine (execution outcome).
# Each event is self-contained and immutable after creation.

########## Action Events (can trigger rule processing)

# Move a piece from one square to another.
# Optionally includes the moving piece (usually added by engine).
MovePieceEvent = Struct.new(:from, :to, :piece)

# Castling move.
# Use `CastleEvent.request(side)` for parser-side creation,
# and `CastleEvent.resolve(...)` for engine-side execution with positions.
class CastleEvent
  SIDES = %i[kingside queenside].freeze
  attr_reader :side, :king_to, :rook_from, :rook_to

  def self.request(side)
    new(side, nil, nil, nil)
  end

  def self.resolve(side, king_to, rook_from, rook_to)
    new(side, king_to, rook_from, rook_to)
  end

  private_class_method :new
  def initialize(side, king_to, rook_from, rook_to)
    @side = side
    @king_to = king_to
    @rook_from = rook_from
    @rook_to = rook_to
  end
end

# En passant move (special pawn capture).
# Captured position is derived, not stored directly.
class EnPassantEvent
  attr_reader :from, :to

  def initialize(from, to)
    @from = from
    @to = to
  end

  def captured_position
    Position.new(to.file, from.rank)
  end
end

# Promotion request: promote piece at to `new_piece`.
PromotePieceEvent = Struct.new(:piece_type)

########## State Events (supporting metadata or consequences)

# Piece removal — e.g., for captures.
# Either position or piece (or both) can be specified.
RemovePieceEvent = Struct.new(:position, :piece)

# A player is in check.
CheckEvent = Struct.new(:color)

# A player is checkmated.
CheckmateEvent = Struct.new(:color)

# Game is drawn for a given reason (e.g., stalemate, repetition).
DrawEvent = Struct.new(:reason)
