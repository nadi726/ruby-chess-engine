# frozen_string_literal: true

require_relative 'board'
require_relative 'game_data'
require_relative 'game_query'
require_relative '../data_definitions/piece'
require_relative '../data_definitions/position'
require_relative '../data_definitions/castling_data'
require 'immutable'

# Represents the immutable state of the game at a specific point in time.
#
# Holds all the information needed to fully describe the current state of a chess game:
# the board layout, which player's turn it is, move history, castling rights, en passant target, and more.
#
# Responsibilities:
# - Answer queries about the current position (through the `query` object).
# - Produce the next GameState by applying a list of valid events (`#apply_events`).
#
# Internal structure:
# - data: A GameData object representing the current game data
# - move_history: An immutable list of event-lists. Each inner list represents the events that made up a single turn.
# - position_signatures: An immutable hash counting position signatures, used for detecting repetition.
# - query: A GameQuery object that provides a high-level interface for interrogating the state.
#
# The design avoids mutable state—each change produces a new GameState, leaving previous states untouched.
# This makes reasoning about the engine easier and enables features like undo and state comparison.
class GameState
  attr_reader :query, :data

  # The state at the game's start
  def self.start
    GameState.new
  end

  def initialize(data: GameData.start, move_history: Immutable::List[], position_signatures: Immutable::Hash[])
    @data = data
    @move_history = move_history
    @position_signatures = position_signatures
    @query = GameQuery.new(@data, @move_history, @position_signatures)
  end

  # Process a sequence of events to produce the next GameState
  # Assumes the event sequence is valid.
  def apply_events(events)
    events = Immutable.from events
    signature_count = @position_signatures.fetch(@data.position_signature, 0)
    signatures = @position_signatures.put(@data.position_signature, signature_count + 1)

    GameState.new(
      data: advance_data(events),
      move_history: @move_history.add(events),
      position_signatures: signatures
    )
  end

  private

  def advance_data(events)
    GameData.new(
      board: advance_board(@data.board, events),
      current_color: @data.other_color,
      en_passant_target: compute_en_passant(events),
      castling_rights: compute_castling_rights(@data.castling_rights, @data.current_color, events),
      halfmove_clock: compute_halfmove_clock(@data.halfmove_clock, events)
    )
  end

  def advance_board(board, events)
    case main_event(events)
    in MovePieceEvent => e
      advance_with_move_piece_event(board, events, e)
    in EnPassantEvent => e
      board.remove(e.captured_position).move(e.from, e.to)
    in CastlingEvent => e
      board.move(e.king_from, e.king_to).move(e.rook_from, e.rook_to)

    # TODO: Confirm this is the intended behaivor
    in nil
      raise "No ActionEvent found in event sequence: #{events.map(&:class)}"
    else
      raise "Unhandled event type: #{events.first.class}"
    end
  end

  def advance_with_move_piece_event(board, events, move_event)
    from, to, piece = move_event.deconstruct
    promote = events.grep(PromotePieceEvent).first
    final_piece = promote ? Piece.new(piece.color, promote.piece_type) : piece

    removals = events.grep(RemovePieceEvent)
    board = removals.reduce(board) { |b, e| b.remove(e.position) }

    board.remove(from).insert(final_piece, to)
  end

  def compute_en_passant(events)
    # Get the last move and ensure it was a pawn moving two steps forward
    move = events.find do |move|
      move.is_a?(MovePieceEvent) && move.piece.type == :pawn &&
        move.from.distance(move.to) == [0, 2]
    end
    return unless move

    # Return the square passed over
    Position[move.from.file, (move.from.rank + move.to.rank) / 2]
  end

  def compute_castling_rights(previous_rights, color, events)
    sides = previous_rights.get_side color
    kingside_rook_pos  = CastlingData.rook_from(color, :kingside)
    queenside_rook_pos = CastlingData.rook_from(color, :queenside)

    sides = case main_event(events)
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

  def compute_halfmove_clock(clock, events)
    reset_clock = events.any? do |e|
      (e.is_a?(MovePieceEvent) && e.piece.type == :pawn) ||
        e.is_a?(RemovePieceEvent) ||
        e.is_a?(EnPassantEvent)
    end

    reset_clock ? 0 : clock + 1
  end

  def main_event(events)
    events.grep(ActionEvent).first
  end
end
