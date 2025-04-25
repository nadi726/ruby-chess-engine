# frozen_string_literal: true

# This file defines various events representing changes and actions in the game.
# It includes board manipulation events, special moves (e.g., castling, en passant), game state changes (e.g., check),
# and special input events (e.g., promotion).
# These events are used by the game engine to manage and execute game logic,
# and by the game interface to track what has occurred and determine the necessary actions,
# such as in the case of ChoosePromotionEvent.

# Game state change events
CheckEvent = Struct.new(:color)
CheckmateEvent = Struct.new(:color)
DrawEvent = Struct.new(:reason) # reason is optional(can be nil)

# Special input events
ChoosePromotionEvent = Struct.new(:position)

# Board manipulation events
MovePieceEvent = Struct.new(:from, :to)
RemovePieceEvent = Struct.new(:position)
PromotePieceEvent = Struct.new(:position, :new_piece)

# A CastleEvent describes the special move "Castling".
# It has two forms:
# - The side-only form is used by the game interface to request castling.
# - The full form, with piece positions, is used by the engine to execute the move.
class CastleEvent
  SIDES = %i[kingside queenside].freeze
  attr_reader :side, :king_to, :rook_from, :rook_to

  def self.from_side(side)
    new(side, nil, nil, nil)
  end

  def self.with_positions(side, king_to, rook_from, rook_to)
    new(side, king_to, rook_from, rook_to)
  end

  def initialize(side, king_to, rook_from, rook_to)
    @side = side
    @king_to = king_to
    @rook_from = rook_from
    @rook_to = rook_to
  end
end

# A EnPassantEvent describes the special move "En Passant".
# It has two forms:
# - The basic form is used by the game interface to request castling.
# - The full form, with the captured piece's position, is used by the engine to execute the move.
class EnPassantEvent
  attr_reader :from, :to, :captured_piece_position

  def self.basic(from, to)
    new(from, to, nil)
  end

  def self.with_capture(from, to, captured_piece_position)
    new(from, to, captured_piece_position)
  end

  def initialize(from, to, captured_piece_position)
    @from = from
    @to = to
    @captured_piece_position = captured_piece_position
  end
end
