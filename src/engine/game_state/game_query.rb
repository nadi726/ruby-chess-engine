# frozen_string_literal: true

require 'immutable'
require_relative 'game_state'
require_relative 'no_legal_moves_helper'

# Provides derived information about the current game state.
#
# GameQuery acts as the single entry point for all game-related queries.
# It exposes methods for:
# - **Check and checkmate detection** (`in_check?`, `in_checkmate?`)
# - **draw detection** ( `must_draw?`, `in_draw?`, and detailed draw queries like `stalemate?` )
# - **Piece interactions** (`piece_attacking?`, `piece_can_move?`)
# - **King and piece lookup** (`current_pieces`, `other_pieces`)
class GameQuery
  include NoLegalMovesHelper

  attr_reader :position, :move_history, :position_signatures, :board

  def initialize(position, move_history = Immutable::List[], position_signatures = Immutable::Hash[])
    @position = position
    @move_history = Immutable.from move_history
    @position_signatures = Immutable.from position_signatures
    @board = position.board # For easier access
  end

  def state
    @state ||= GameState.new(position: position, move_history: move_history, position_signatures: position_signatures)
  end

  # Determines if a piece at the given square is attacking a target square.
  def piece_attacking?(from, target_square)
    piece = board.get(from)
    target_piece = board.get(target_square)
    return false unless piece && target_piece && piece.color != target_piece.color

    piece.threatened_squares(board, from).include?(target_square)
  end

  def piece_can_move?(from, to)
    piece = board.get(from)
    all_pieces.include?(piece) && board.get(to).nil? && piece.moves(board, from).include?(to)
  end

  # returns true if the king of the specified color is in check
  def in_check?(color = @position.current_color)
    _k, king_pos = @board.pieces_with_squares(color: color, type: :king).first
    other_pieces_squares = @board.pieces_with_squares(color: color == :white ? :black : :white)
    other_pieces_squares.any? do |_, piece_pos|
      piece_attacking?(piece_pos, king_pos)
    end
  end

  # returns true if the king of the specified color is in checkmate
  def in_checkmate?(color = @position.current_color)
    in_check?(color) && no_legal_moves?(color)
  end

  # Returns true if the game must end in a draw
  def must_draw?
    stalemate? || insufficient_material?
  end

  # returns true if the current player can request a draw to force the game to end
  def can_draw?
    threefold_repetition? || fifty_move_rule?
  end

  # returns true if the game is in stalemate
  def stalemate?
    !in_check? && no_legal_moves?(@position.current_color)
  end

  # According to FIDE rules, as listed here:
  # https://www.chess.com/terms/draw-chess#dead-position
  def insufficient_material?
    white_types = @board.find_pieces(color: :white).map(&:type)
    black_types = @board.find_pieces(color: :black).map(&:type)

    INSUFFICIENT_COMBINATIONS.any? do |combo|
      match_combination?(white_types, black_types, combo) ||
        match_combination?(black_types, white_types, combo)
    end
  end

  def threefold_repetition?
    @position_signatures.fetch(@position.signature, 0) >= 3
  end

  def fifty_move_rule?
    @position.halfmove_clock >= 100
  end

  def current_pieces
    @board.find_pieces(color: @position.current_color)
  end

  def other_pieces
    @board.find_pieces(color: @position.other_color)
  end

  def all_pieces
    board.find_pieces
  end

  INSUFFICIENT_COMBINATIONS = [
    [%i[king], %i[king]],
    [%i[king bishop], %i[king]],
    [%i[king knight], %i[king]],
    [%i[king bishop], %i[king bishop], :same_color_bishops]
  ].freeze

  private

  # Match piece type combination for #insufficient_material?
  def match_combination?(types1, types2, combo)
    pattern1, pattern2, condition = combo
    return false unless types1.sort == pattern1.sort && types2.sort == pattern2.sort

    condition == :same_color_bishops ? same_color_bishops? : true
  end

  # Returns true if both sides have bishops on the same color squares
  # (only relevant when each side has exactly one bishop)
  # Used in #insufficient_material?
  def same_color_bishops?
    bishop_pos1 = @board.pieces_with_squares(color: :white, type: :bishop).first&.last
    bishop_pos2 = @board.pieces_with_squares(color: :black, type: :bishop).first&.last
    return false unless bishop_pos1 && bishop_pos2

    file_distance, rank_distance = bishop_pos1.distance(bishop_pos2)
    (file_distance + rank_distance).even?
  end
end
