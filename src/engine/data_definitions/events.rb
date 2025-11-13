# frozen_string_literal: true

require 'immutable'
require 'wholeable'
require_relative 'castling_data'
require_relative 'square'
require_relative 'piece'
require_relative 'colors'

# Events are immutable records representing game actions or state changes.
# They are produced by the parser (user intent) and by the engine (execution outcome).
#
# The parser may generate incomplete events.
# The event handler **must** populate all *required* fields, but **must not** populate *optional* fields.
#
# **NOTE:** The declaration of a field as optional is made explicitly within the event subclass definition.
class GameEvent
  include Wholeable[:assertions]

  def initialize(assertions: nil)
    # Assertions reflect the annotations sometimes appended to algebraic chess notation moves (e.g. "!", "?", "e.p.").
    # Handlers must not depend on them for correctness.
    # If assertions state plain falsehoods (e.g. claim check when not in check),
    # the event may be considered invalid.
    @assertions = assertions

    # Get `GameEvent#inspect` and `#to_s` specifically, since `Wholeable` overrides them
    define_singleton_method(:inspect) do
      GameEvent.instance_method(:inspect).bind(self).call
    end

    define_singleton_method(:to_s) do
      GameEvent.instance_method(:to_s).bind(self).call
    end
  end

  def inspect
    filled, nils = to_h.partition { |_, v| !v.nil? }
    filled_s = filled.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
    nils = nils.map(&:first)
    parts = [
      filled_s.empty? ? nil : filled_s,
      nils.empty? ? nil : "nil: [#{nils.join(', ')}]"
    ].compact
    "#<#{self.class} #{parts.join(', ')}>"
  end

  def to_s = inspect

  def with(*, **)
    raise NotImplementedError, "#with doesn't work for wholeables defined with positional arguments"
  end
end

# Move a piece from one square to another.
# `captured` and `promote_to` are optional - only for captures and promotion, respectively.
class MovePieceEvent < GameEvent
  include Wholeable[:piece, :from, :to, :captured, :promote_to]

  def initialize(piece, from, to, captured = nil, promote_to = nil, **)
    super(**)
    @piece = piece
    @from = from
    @to = to
    @captured = captured
    @promote_to = promote_to
  end

  def capture(captured_square = nil, captured_piece = nil)
    with(captured: CaptureData[captured_square, captured_piece])
  end

  def promote(piece_type)
    with(promote_to: piece_type)
  end

  def with(piece: self.piece, from: self.from, to: self.to, captured: self.captured, promote_to: self.promote_to,
           assertions: self.assertions)
    self.class.new(piece, from, to, captured, promote_to,
                   assertions: assertions)
  end
end

# Castling move.
class CastlingEvent < GameEvent
  include Wholeable[:side, :color]

  SIDES = %i[kingside queenside].freeze

  def initialize(side, color, **)
    super(**)
    @side = side # One of: :kingside, :queenside
    @color = color
  end

  def king_from
    ensure_validity
    CastlingData.king_from(color, side)
  end

  def king_to
    ensure_validity
    CastlingData.king_to(color, side)
  end

  def rook_from
    ensure_validity
    CastlingData.rook_from(color, side)
  end

  def rook_to
    ensure_validity
    CastlingData.rook_to(color, side)
  end

  def with(color: self.color, side: self.side, assertions: self.assertions)
    self.class.new(color, side, assertions: assertions)
  end

  private

  def ensure_validity
    return if SIDES.include?(side) && COLORS.include?(color)

    raise ArgumentError, "Invalid fields for CastlingEvent: #{color}, #{side}"
  end
end

# En passant move.
class EnPassantEvent < GameEvent
  include Wholeable[:color, :from, :to]

  def initialize(color, from, to, **)
    super(**)
    @color = color
    @from = from
    @to = to
  end

  def piece
    Piece[color, :pawn]
  end

  def captured
    opponent_color = if COLORS.include?(color)
                       color == :white ? :black : :white
                     end

    CaptureData[Square[to&.file, from&.rank], Piece[opponent_color, :pawn]]
  end

  def with(color: self.color, from: self.from, to: self.to, assertions: self.assertions)
    self.class.new(color, from, to, assertions: assertions)
  end
end

# Information about a captured piece. Used as a field/getter in certain events.
CaptureData = Data.define(:square, :piece) do
  def initialize(square: nil, piece: nil)
    super
  end
end
