# frozen_string_literal: true

require 'immutable'

# Provides derived information about the current game state.
# Centralizes logic for answering queries such as possible movement, attacks, or draw conditions.
class GameQuery
  attr_reader :data, :move_history, :position_signatures, :board

  def initialize(data, move_history = Immutable::List[], position_signatures = Immutable::Hash[])
    @data = data
    @move_history = move_history
    @position_signatures = position_signatures
    @board = data.board # For easier access
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
    current_pieces.include?(piece) && board.get(to).nil? && piece.moves(board, from).include?(to)
  end

  # returns the current color if the king is in check, otherwise nil
  def check
    _k, king_pos = @board.pieces_with_positions(color: @data.current_color, type: :king).first
    other_pieces_positions = @board.pieces_with_positions(color: @data.other_color)
    is_in_check = other_pieces_positions.any? do |_, piece_pos|
      piece_attacking?(piece_pos, king_pos)
    end

    is_in_check ? @data.current_color : nil
  end

  def in_check?
    !check.nil?
  end

  # returns: :white, :black, or nil
  def checkmate
    # TODO
  end

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
