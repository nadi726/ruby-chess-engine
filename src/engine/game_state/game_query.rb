# frozen_string_literal: true

require 'immutable'
require_relative 'game_state'
require_relative 'no_legal_moves_helper'

# Provides derived information about the current game state.
#
# GameQuery acts as the single entry point for all game-related queries.
# It exposes methods for:
# - **Check and checkmate detection** (`in_check?`, `in_checkmate?`)
# - **draw detection** ( `must_draw?`, `in_draw?`, and detailed draw queries like `in_stalemate?` )
# - **Piece interactions** (`piece_attacking?`, `piece_can_move?`)
# - **King and piece lookup** (`current_pieces`, `other_pieces`)
class GameQuery
  include NoLegalMovesHelper

  attr_reader :data, :move_history, :position_signatures, :board

  def initialize(data, move_history = Immutable::List[], position_signatures = Immutable::Hash[])
    @data = data
    @move_history = Immutable.from move_history
    @position_signatures = Immutable.from position_signatures
    @board = data.board # For easier access
  end

  def state
    @state ||= GameState.new(data: data, move_history: move_history, position_signatures: position_signatures)
  end

  # Determines if a piece at the given position is attacking a target position.
  def piece_attacking?(from, target_position)
    piece = board.get(from)
    target_piece = board.get(target_position)
    return false unless piece && target_piece && piece.color != target_piece.color

    piece.threatened_squares(board, from).include?(target_position)
  end

  def piece_can_move?(from, to)
    piece = board.get(from)
    all_pieces.include?(piece) && board.get(to).nil? && piece.moves(board, from).include?(to)
  end

  # returns true if the king of the specified color is in check
  def in_check?(color = @data.current_color)
    _k, king_pos = @board.pieces_with_positions(color: color, type: :king).first
    other_pieces_positions = @board.pieces_with_positions(color: color == :white ? :black : :white)
    other_pieces_positions.any? do |_, piece_pos|
      piece_attacking?(piece_pos, king_pos)
    end
  end

  # returns true if the king of the specified color is in checkmate
  def in_checkmate?(color = @data.current_color)
    in_check?(color) && no_legal_moves?(color)
  end

  # Returns true if the game must end in a draw
  def must_draw?
    in_stalemate? || insufficient_material?
  end

  # returns true if the current player can request a draw
  def can_draw?
    threefold_repetition? || fifty_move_rule?
  end

  # returns true if the game is in stalemate
  def in_stalemate?
    !in_check? && no_legal_moves?(@data.current_color)
  end

  # Optional detailed draw queries
  def insufficient_material?; end
  def threefold_repetition?; end
  def fifty_move_rule?; end

  def current_pieces
    @board.find_pieces(color: @data.current_color)
  end

  def other_pieces
    @board.find_pieces(color: @data.other_color)
  end

  def all_pieces
    board.find_pieces
  end
end
