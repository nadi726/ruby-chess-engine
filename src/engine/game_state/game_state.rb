# frozen_string_literal: true

require_relative 'board'
require_relative 'game_data'
require_relative 'game_query'
require_relative '../data_definitions/piece'
require_relative '../data_definitions/position'
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
  attr_reader :query

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
      board: advance_board(@data.board),
      current_color: @data.current_color == :white ? :black : :white,
      en_passant_target: compute_en_passant(events),
      castling_rights: compute_castling_rights(@data.castling_rights, events),
      halfmove_clock: compute_halfmove_clock(@data.halfmove_clock, events)
    )
  end

  def advance_board(board)
    # TODO
    board # placeholder
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

  def compute_halfmove_clock(clock, events)
    # TODO
    clock + 1
  end

  def remove_piece(position)
    # TODO
  end

  def move_piece(from, to)
    # TODO
  end
end
