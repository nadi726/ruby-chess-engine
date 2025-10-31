# frozen_string_literal: true

require 'data_definitions/square'

# Expects a space-separated string of squares (e.g., 'a1 d6')
# And returns an array of Square objects
def parse_squares(squares)
  squares.split.map do |pos|
    Square[pos[0].to_sym, pos[1].to_i]
  end
end

# Fills a game board, given an array of squares for white and black pieces.
#
# - All squares not listed return nil
# - Each square for white pieces returns a double with color: :white
# - Each square for black pieces returns a double with color: :black
def fill_board_by_square(white_squares, black_squares)
  # Start with an array of 64 nils
  squares = Array.new(64)

  # Place white pieces
  white_squares.each do |pos|
    idx = (pos.to_a[0] * Board::SIZE) + pos.to_a[1]
    squares[idx] = Piece[:white, :pawn]
  end

  # Place black pieces
  black_squares.each do |pos|
    idx = (pos.to_a[0] * Board::SIZE) + pos.to_a[1]
    squares[idx] = Piece[:black, :pawn]
  end

  Board.from_flat_array(squares)
end

# Takes an array of pairs, where the first element of the pair is a Piece
# and the second element of the pair is a Square object.
#
# Returns a Board instance with all pieces inserted at their corresponding squares.
def fill_board(pieces_with_squares, board: Board.empty)
  pieces_with_squares.reduce(board) { |b, val| b.insert(*val) }
end

RSpec::Matchers.define :be_a_successful_handler_result do
  match(&:success?)

  failure_message do |actual|
    "expected success, but got failure.\nError message: #{actual.error}"
  end
end

RSpec::Matchers.define :be_a_failed_handler_result do
  match(&:failure?)

  failure_message do
    'expected failure, but got success.'
  end
end

RSpec::Matchers.define :have_piece_at do |pos, expected_piece|
  match do |actual_state|
    actual_piece = actual_state.query.board.get(pos)
    actual_piece == expected_piece
  end

  failure_message do |actual_state|
    actual_piece = actual_state.query.board.get(pos)
    "Expected #{pos} to have #{expected_piece || 'empty'}, but got #{actual_piece || 'empty'}"
  end
end

RSpec::Matchers.define :be_empty_at do |pos|
  match do |actual_state|
    have_piece_at(pos, nil).matches?(actual_state)
  end
end
