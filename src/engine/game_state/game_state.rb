# frozen_string_literal: true

require 'immutable'
require_relative 'game_query'
require_relative 'game_history'
require_relative '../errors'
require_relative '../data_definitions/piece'
require_relative '../data_definitions/square'
require_relative '../data_definitions/board'
require_relative '../data_definitions/position'
require_relative '../data_definitions/events'
require_relative '../data_definitions/primitives/colors'
require_relative '../data_definitions/primitives/castling_data'

# Represents the immutable state of the game at a specific point in time.
#
# Holds all the information needed to fully describe the current state of a chess game:
# the board layout, which player's turn it is, history, castling rights, en passant target, and more.
#
# Responsibilities:
# - Answer queries about the current position (through the `GameQuery` object).
# - Produce the next `GameState` by applying a valid event (`#apply_event`).
#
# Internal structure:
# - position: A `Position` object representing the current game position
# - history: A `GameHistory` object representing all that happened since the creation of the originating `GameState`.
# - query: A `GameQuery` object that provides a high-level interface for interrogating the state.
#
# The design avoids mutable state — each change produces a new `GameState`, leaving previous states untouched.
# This makes reasoning about the engine easier and enables features like undo and state comparison.
class GameState
  attr_reader :query, :position, :history

  # The state at the game's start
  def self.start
    GameState.new(position: Position.start, history: GameHistory.start)
  end

  # Load a new gamestate from position. Suitable for FEN.
  def self.load(position)
    history = GameHistory.start.with(start_position: position)
    GameState.new(position: position, history: history)
  end

  # Make a new `GameState` from an existing one.
  # Good for computations requiring forking the state.
  def with(position: @position, history: @history)
    GameState.new(position: position, history: history)
  end

  # Low-level initialization, loads all fields. Use with caution.
  def initialize(position: Position.start, history: GameHistory.start)
    unless position.is_a?(Position) && history.is_a?(GameHistory)
      raise ArgumentError,
            "One or more invalid arguments: #{position}, #{history}"
    end

    @position = position
    @history = history
    @query = GameQuery.new(@position, @history)
  end

  # Process an event to produce the next `GameState`
  # Assumes the event is valid and complete.
  def apply_event(event)
    raise ArgumentError unless event.is_a?(GameEvent)

    GameState.new(
      position: advance_position(event),
      history: advance_history(event)
    )
  end

  private

  def advance_history(event)
    signatures = history.position_signatures
    signature_count = signatures.fetch(@position.signature, 0)
    new_signatures = signatures.put(@position.signature, signature_count + 1)

    history.with(moves: history.moves.add(event), position_signatures: new_signatures)
  end

  def advance_position(event)
    Position.new(
      board: advance_board(event),
      current_color: @position.other_color,
      en_passant_target: compute_en_passant(event),
      castling_rights: compute_castling_rights(event),
      halfmove_clock: compute_halfmove_clock(event)
    )
  rescue InvalidEventError; raise
  rescue InvariantViolationError => e
    raise InvalidEventError,
          "Invariant violation during event application: #{e.class} - #{e.message}\nEvent: #{event}"
  end

  def advance_board(event)
    board = @position.board
    case event
    in MovePieceEvent
      advance_with_move_piece_event(board, event)
    in EnPassantEvent => e
      board.remove(e.captured.square).move(e.from, e.to)
    in CastlingEvent => e
      board.move(e.king_from, e.king_to).move(e.rook_from, e.rook_to)
    else
      raise InvalidEventError, "Unhandled event type: #{event.class}"
    end
  end

  def advance_with_move_piece_event(board, event)
    final_piece = event.promote_to ? Piece.new(event.piece.color, event.promote_to) : event.piece

    # capture if applicable
    board = board.remove(event.captured.square) if event.captured
    # move the piece
    board.remove(event.from).insert(final_piece, event.to)
  end

  def compute_en_passant(event)
    # Get the last move and ensure it was a pawn moving two steps forward
    return unless event.is_a?(MovePieceEvent) && event.piece.type == :pawn &&
                  event.from.distance(event.to) == [0, 2]

    # Return the square passed over
    sq = Square[event.from.file, (event.from.rank + event.to.rank) / 2]
    raise InvariantViolationError, "Invalid en passant target: #{sq}" unless sq.valid?

    sq
  end

  def compute_castling_rights(event)
    current_color_sides = castling_sides_for_current_color(event)
    other_color_sides = castling_sides_for_other_color(event)
    @position.castling_rights.with(@position.current_color => current_color_sides,
                                   @position.other_color => other_color_sides)
  end

  # Helpers for computing castling rights
  def castling_sides_for_current_color(event)
    color = @position.current_color
    sides = @position.castling_rights.sides color

    case event
    in MovePieceEvent => e
      if e.piece.type == :king
        sides.with(kingside: false, queenside: false)
      elsif e.from == CastlingData.rook_from(color, :kingside)
        sides.with(kingside: false)
      elsif e.from == CastlingData.rook_from(color, :queenside)
        sides.with(queenside: false)
      else
        sides
      end
    in CastlingEvent
      sides.with(kingside: false, queenside: false)
    else
      sides
    end
  end

  def castling_sides_for_other_color(event)
    color = @position.other_color
    sides = @position.castling_rights.sides color

    return sides unless event.is_a?(MovePieceEvent)

    captured = event.captured
    return sides if captured.nil? || captured.piece.type != :rook

    case captured.square
    when CastlingData.rook_from(color, :kingside)
      sides.with(kingside: false)
    when CastlingData.rook_from(color, :queenside)
      sides.with(queenside: false)
    else
      sides
    end
  end

  def compute_halfmove_clock(event)
    reset_clock = (event.is_a?(MovePieceEvent) && (event.piece.type == :pawn || event.captured)) ||
                  event.is_a?(EnPassantEvent)

    reset_clock ? 0 : @position.halfmove_clock + 1
  end
end
