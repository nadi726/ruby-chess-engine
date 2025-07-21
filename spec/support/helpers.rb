# frozen_string_literal: true

require 'data_definitions/position'

# Expects a space-separated string of positions (e.g., 'a1 d6')
# And returns an array of Position objects
def parse_positions(positions)
  positions.split.map do |pos|
    Position[pos[0].to_sym, pos[1].to_i]
  end
end

# Fills a game board, given an array of
# positions for white and black pieces.
#
# - All positions not listed return nil
# - Each position for white pieces returns a double with color: :white
# - Each position for black pieces returns a double with color: :black
def fill_board_by_position(white_positions, black_positions)
  # Start with an array of 64 nils
  squares = Array.new(64)

  # Place white pieces
  white_positions.each do |pos|
    idx = (pos.to_a[0] * Board::SIZE) + pos.to_a[1]
    squares[idx] = double('Piece', color: :white)
  end

  # Place black pieces
  black_positions.each do |pos|
    idx = (pos.to_a[0] * Board::SIZE) + pos.to_a[1]
    squares[idx] = double('Piece', color: :black)
  end

  Board.from_flat_array(squares)
end

# Takes an array of pairs, where the first element of the pair is a Piece
# and the second element of the pair is a Position object.
#
# Returns a Board instance with all pieces inserted at their corresponding positions.
def fill_board(pieces_with_positions, board: Board.empty)
  pieces_with_positions.reduce(board) { |b, val| b.insert(*val) }
end

RSpec::Matchers.define :be_a_successful_handler_result do
  match do |actual|
    actual[:success] == true
  end

  failure_message do |actual|
    "expected success, but got failure.\nError message: #{actual[:error]}"
  end
end

RSpec::Matchers.define :be_a_failed_handler_result do
  match do |actual|
    actual[:success] == false
  end

  failure_message do
    'expected failure, but got success.'
  end
end
