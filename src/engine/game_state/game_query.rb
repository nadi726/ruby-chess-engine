# frozen_string_literal: true

require 'immutable'
require_relative 'game_state'
require_relative 'game_history'
require_relative 'legal_moves_helper'
require_relative '../data_definitions/square'
require_relative '../data_definitions/position'
require_relative '../data_definitions/primitives/colors'

# Provides derived information about the current game state.
#
# `GameQuery` acts as the single entry point for all game-related queries.
# It exposes methods for:
# - **legal moves enumeration** (`legal_moves(color)`)
# - **Check and checkmate detection** (`in_check?`, `in_checkmate?`)
# - **draw detection** ( `must_draw?`, `in_draw?`, and detailed draw queries like `stalemate?` )
# - **Pieces and squares relations** (`piece_attacking?`, `piece_can_move?`, `square_attacked?`)
class GameQuery
  include LegalMovesHelper

  INVALID_ARGUMENT = :invalid
  attr_reader :position, :history

  def initialize(position, history = GameHistory.start)
    unless position.is_a?(Position) && history.is_a?(GameHistory)
      raise ArgumentError,
            "One or more invalid arguments for GameQuery: #{position}, #{history}"
    end

    @position = position
    @history = history
  end

  def with(position: @position, history: @history)
    self.class.new(position, history)
  end

  def state
    @state ||= GameState.new(position: position, history: history)
  end

  # For easier access
  def board = position.board
  def position_signatures = history.position_signatures

  # Determine whether a piece at square "from" can move to "to" without capturing,
  # not taking into account other considerations like pins.
  def piece_can_move?(from, to)
    return INVALID_ARGUMENT unless valid_square?(from) && valid_square?(to)

    piece = board.get(from)
    board.find_pieces.include?(piece) && board.get(to).nil? && piece.moves(board, from).include?(to)
  end

  # Determines if a piece at the given square is attacking a target square.
  def piece_attacking?(from, target_square)
    return INVALID_ARGUMENT unless valid_square?(from) && valid_square?(target_square)

    piece = board.get(from)
    target_piece = board.get(target_square)
    return false unless piece && piece.color != target_piece&.color

    piece.threatened_squares(board, from).include?(target_square)
  end

  # Determines whether the given square is attacked by a piece of the specified color
  def square_attacked?(attacked_square, color = @position.other_color)
    return INVALID_ARGUMENT unless valid_square?(attacked_square) && COLORS.include?(color)

    other_pieces_squares = board.pieces_with_squares(color: color)
    other_pieces_squares.any? do |_p, attacking_square|
      piece_attacking?(attacking_square, attacked_square)
    end
  end

  # returns true if the king of the specified color is in check
  def in_check?(color = @position.current_color)
    return INVALID_ARGUMENT unless COLORS.include?(color)

    _k, king_square = board.pieces_with_squares(color: color, type: :king).first
    square_attacked?(king_square, flip_color(color))
  end

  # returns true if the king of the specified color is in checkmate
  def in_checkmate?(color = @position.current_color)
    return INVALID_ARGUMENT unless COLORS.include?(color)

    in_check?(color) && legal_moves(color).none?
  end

  # Returns true if the game must end in a draw
  def must_draw?
    stalemate? || insufficient_material? || fivefold_repetition?
  end

  # returns true if the current player can request a draw to force the game to end
  def can_draw?
    threefold_repetition? || fifty_move_rule?
  end

  # returns true if the game is in stalemate
  def stalemate?
    !in_check? && legal_moves(@position.current_color).none?
  end

  # According to FIDE rules, as listed here:
  # https://www.chess.com/terms/draw-chess#dead-position
  def insufficient_material?
    white_types = board.find_pieces(color: :white).map(&:type)
    black_types = board.find_pieces(color: :black).map(&:type)

    INSUFFICIENT_COMBINATIONS.any? do |combo|
      match_combination?(white_types, black_types, combo) ||
        match_combination?(black_types, white_types, combo)
    end
  end

  # Added by FIDE in 2014
  def fivefold_repetition?
    @history.position_signatures.fetch(@position.signature, 0) >= 5
  end

  def threefold_repetition?
    @history.position_signatures.fetch(@position.signature, 0) >= 3
  end

  def fifty_move_rule?
    @position.halfmove_clock >= 100
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
    bishop_pos1 = board.pieces_with_squares(color: :white, type: :bishop).first&.last
    bishop_pos2 = board.pieces_with_squares(color: :black, type: :bishop).first&.last
    return false unless bishop_pos1 && bishop_pos2

    file_distance, rank_distance = bishop_pos1.distance(bishop_pos2)
    (file_distance + rank_distance).even?
  end

  def valid_square?(square)
    square.is_a?(Square) && square.valid?
  end
end
