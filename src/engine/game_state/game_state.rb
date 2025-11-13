# frozen_string_literal: true

require_relative 'board'
require_relative 'position'
require_relative 'game_query'
require_relative '../data_definitions/piece'
require_relative '../data_definitions/square'
require_relative '../data_definitions/castling_data'
require_relative '../data_definitions/events'
require 'immutable'

# Represents the immutable state of the game at a specific point in time.
#
# Holds all the information needed to fully describe the current state of a chess game:
# the board layout, which player's turn it is, move history, castling rights, en passant target, and more.
#
# Responsibilities:
# - Answer queries about the current position (through the `GameQuery` object).
# - Produce the next `GameState` by applying a valid event (`#apply_event`).
#
# Internal structure:
# - position: A `Position` object representing the current game position
# - move_history: An immutable list of events, in the order they were applied.
# - position_signatures: An immutable hash counting position signatures, used for detecting repetition.
# - query: A `GameQuery` object that provides a high-level interface for interrogating the state.
#
# The design avoids mutable state — each change produces a new `GameState`, leaving previous states untouched.
# This makes reasoning about the engine easier and enables features like undo and state comparison.
class GameState
  attr_reader :query, :position

  # The state at the game's start
  def self.start
    GameState.new
  end

  def initialize(position: Position.start, move_history: Immutable::List[], position_signatures: Immutable::Hash[])
    @position = position
    @move_history = move_history
    @position_signatures = position_signatures
    @query = GameQuery.new(@position, @move_history, @position_signatures)
  end

  # Process an event to produce the next `GameState`
  # Assumes the event is valid and complete.
  def apply_event(event)
    raise ArgumentError unless event.is_a?(GameEvent)

    signature_count = @position_signatures.fetch(@position.signature, 0)
    signatures = @position_signatures.put(@position.signature, signature_count + 1)

    GameState.new(
      position: advance_position(event),
      move_history: @move_history.add(event),
      position_signatures: signatures
    )
  end

  private

  def advance_position(event)
    Position.new(
      board: advance_board(@position.board, event),
      current_color: @position.other_color,
      en_passant_target: compute_en_passant(event),
      castling_rights: compute_castling_rights(@position.castling_rights, @position.current_color, event),
      halfmove_clock: compute_halfmove_clock(@position.halfmove_clock, event)
    )
  rescue InvalidEventError; raise
  rescue InvariantViolationError => e
    raise InvalidEventError,
          "Invariant violation during event application: #{e.class} - #{e.message}\nEvent: #{event}"
  end

  def advance_board(board, event)
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

  def compute_castling_rights(previous_rights, color, event)
    sides = previous_rights.get_side color
    kingside_rook_pos  = CastlingData.rook_from(color, :kingside)
    queenside_rook_pos = CastlingData.rook_from(color, :queenside)

    sides = case event
            in MovePieceEvent => e
              if e.piece.type == :king
                sides.with(kingside: false, queenside: false)
              elsif e.from == kingside_rook_pos
                sides.with(kingside: false)
              elsif e.from == queenside_rook_pos
                sides.with(queenside: false)
              else
                sides
              end
            in CastlingEvent
              sides.with(kingside: false, queenside: false)
            else
              sides
            end
    previous_rights.with(color => sides)
  end

  def compute_halfmove_clock(clock, event)
    reset_clock = (event.is_a?(MovePieceEvent) && (event.piece.type == :pawn || event.captured)) ||
                  event.is_a?(EnPassantEvent)

    reset_clock ? 0 : clock + 1
  end
end
