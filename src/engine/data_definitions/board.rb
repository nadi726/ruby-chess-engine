# frozen_string_literal: true

require_relative 'piece'
require_relative 'square'
require_relative '../errors'
require_relative 'components/persistent_array'

# `Board` is an immutable chessboard representation.
# Each square is mapped to either a piece or nil, using `Square` objects for coordinates.
# Provides query methods (e.g., `#get`, `#pieces_with_squares`) to inspect board state,
# and manipulation methods that return new `Board` instances with the desired changes.
# Designed for safe, functional-style updates and efficient state sharing.
class Board
  SIZE = 8 # the board dimensions

  # Constructs a `Board` from a flat array of 64 items.
  # Each item's index maps to a board square as follows:
  # 0 -> a1, 2 -> b1, ... 8 -> a2, ... 63 -> h8
  # Each item should be a `Piece` or nil, representing the contents of that square.
  def self.from_flat_array(values)
    raise ArgumentError, 'Expected 64 elements' unless values.size == SIZE * SIZE
    raise ArgumentError, 'Expected nil or Piece objects' unless values.all? { it.nil? || it.is_a?(Piece) }

    array = PersistentArray.from_values(values)
    new(array)
  end

  # An empty board
  def self.empty
    from_flat_array(Array.new(SIZE * SIZE))
  end

  # A board with all pieces set up at their starting squares
  def self.start
    back_row = %i[rook knight bishop queen king bishop knight rook]
    ranks = [
      back_row.map { |t| Piece.new(:white, t) }, # Rank 1
      Array.new(8) { Piece.new(:white, :pawn) }, # Rank 2
      Array.new(4) { Array.new(8) }, # Ranks 3–6
      Array.new(8) { Piece.new(:black, :pawn) }, # Rank 7
      back_row.map { |t| Piece.new(:black, t) } # Rank 8
    ]

    from_flat_array(ranks.flatten)
  end

  # Use only internally
  def initialize(array)
    @array = array
  end

  ######## Queries

  # Get the piece at the given square, or nil if the square is unoccupied
  def get(square)
    index = square_to_index(square)
    @array.get(index)
  end

  # Returns an array of all pieces, with their squares, matching the criteria.
  # The result is an array of elements of the form: [piece, square]
  # If type or color is nil, that attribute is ignored.
  # Examples:
  #   All black pieces: find_pieces(color: :black)
  #   All pieces:       find_pieces
  #   White rooks:      find_pieces(type: :rook, color: :white)
  def pieces_with_squares(color: nil, type: nil)
    @array.filter_map.with_index do |piece, index|
      next if piece.nil?

      [piece, index_to_square(index)] if [nil, piece.type].include?(type) && [nil, piece.color].include?(color)
    end
  end

  # Returns an array of all pieces matching the criteria.
  # Internally delegates to `#pieces_with_squares`, stripping the squares.
  def find_pieces(color: nil, type: nil)
    pieces_with_squares(color: color, type: type).map(&:first)
  end

  ######## Manipulation

  def move(from, to)
    from_index = square_to_index from
    piece = @array.get from_index
    to_index = square_to_index to
    raise BoardManipulationError, 'No piece to move' if piece.nil?
    raise BoardManipulationError, 'Destination is already occupied' unless @array.get(to_index).nil?
    raise BoardManipulationError, 'Cannot move to the same square' if from == to

    Board.new(@array.set(from_index, nil).set(to_index, piece))
  end

  def remove(square)
    index = square_to_index square
    raise BoardManipulationError, 'Square is unoccupied' if get(square).nil?

    Board.new(@array.set(index, nil))
  end

  # Inserts the given piece to an empty square
  def insert(piece, square)
    index = square_to_index(square)
    raise ArgumentError, 'Not a valid piece' unless piece.is_a?(Piece)
    raise BoardManipulationError, 'Square is occupied' unless @array.get(index).nil?

    Board.new(@array.set(index, piece))
  end

  # For debugging mainly
  def to_s # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    rows = []
    rows << '   a b c d e f g h'
    rows << ' ┌─────────────────┐'
    (0...SIZE).each do |row|
      row_str = "#{row + 1}│ "
      (0...SIZE).each do |col|
        index = square_to_index(Square.from_index(row, col))
        piece = @array.get(index)
        row_str += if piece
                     "#{piece} "
                   else
                     (row + col).odd? ? '□ ' : '■ '
                   end
      end
      rows << "#{row_str.chomp}│#{row + 1}"
    end
    rows << ' └─────────────────┘'
    rows << '   a b c d e f g h'
    rows.join("\n")
  end

  def inspect
    "#<Board #{pieces_with_squares.map { |piece, pos| "#{piece}@#{pos}" }.join(', ')}>"
  end

  def ==(other)
    other.is_a?(Board) && pieces_with_squares == other.pieces_with_squares
  end

  def eql?(other)
    self == other
  end

  def hash
    # Doesn't use the exact same hash as `#pieces_with_squares` to avoid clashes
    [pieces_with_squares, 0].hash
  end

  private

  def square_to_index(square)
    raise ArgumentError, "#{square.inspect} is not a Square" unless square.is_a?(Square)
    raise InvalidSquareError, "#{square.inspect} is not a valid square" unless square.valid?

    row, col = square.to_a
    (row * SIZE) + col
  end

  def index_to_square(index)
    row, col = index.divmod(SIZE)
    Square.from_index(row, col)
  end
end
