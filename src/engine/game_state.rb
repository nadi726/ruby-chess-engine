# frozen_string_literal: true

require_relative 'data_definitions/piece'
require_relative 'data_definitions/position'
require 'ice_nine'
require 'ice_nine/core_ext/object'

# The GameState is responsible solely for the manipluation of the state and giving information about it.
# It does not include any rule-checking logic.
class GameState
  def initialize(white_pieces: nil, black_pieces: nil, current_color: :white, move_history: [])
    @white_pieces = white_pieces || starting_pieces(:white)
    @black_pieces = black_pieces || starting_pieces(:black)
    @current_color = current_color
    @move_history = move_history
  end

  def apply_events(events)
    # TODO
  end

  # query methods
  def piece_at(position)
    all_pieces.find { |piece| piece.position == position }
  end

  def piece_by(color, symbol)
    # TODO
  end

  def piece_attacking?(from, target_position)
    piece = piece_at(from)
    target_piece = piece_at(target_position)
    return false unless current_pieces.include?(piece) && other_pieces.include?(target_piece)

    piece.threatened_squares(state: self).include?(target_position)
  end

  def piece_can_move?(from, to)
    piece = piece_at(from)
    current_pieces.include?(piece) && piece_at(to).nil? && piece.moves(state: self).include?(to)
  end

  # returns: :white, :black, or nil
  def check
    # TODO
  end

  # returns: :white, :black, or nil
  def checkmate
    # TODO
  end

  def current_pieces
    @current_color == :white ? @white_pieces : @black_pieces
  end

  def other_pieces
    @current_color == :white ? @black_pieces : @white_pieces
  end

  def all_pieces
    @white_pieces + @black_pieces
  end

  def move_history
    @move_history.deep_freeze
  end

  private

  def switch_color
    @current_color = @current_color == :white ? :black : :white
  end

  def remove_piece(position)
    # TODO
  end

  def move_piece(from, to)
    # TODO
  end
end

private

def starting_pieces(color) # rubocop:disable Metrics/MethodLength
  raise ArgumentError, "Unknown color #{color}" unless %i[white black].include?(color)

  ranks = color == :white ? [1, 2] : [8, 7]
  back_rank, front_rank = ranks

  back_row_order = %i[rook knight bishop queen king bishop knight rook]
  back_row = back_row_order.map.with_index do |symbol, i|
    Piece.new(color, symbol, Position.new(Position::FILES[i], back_rank))
  end

  front_row = Position::FILES.map do |file|
    Piece.new(color, :pawn, Position.new(file, front_rank))
  end

  back_row + front_row
end
