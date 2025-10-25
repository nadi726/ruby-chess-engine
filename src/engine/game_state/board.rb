# frozen_string_literal: true

require_relative 'persistent_array'
require_relative '../data_definitions/position'
require_relative '../data_definitions/piece'
require_relative '../errors'

# Board is an immutable chessboard representation.
# Each square is mapped to either a piece or nil, using Position objects for coordinates.
# Provides query methods (e.g., #get, #pieces_with_positions) to inspect board state,
# and manipulation methods that return new Board instances with the desired changes.
# Designed for safe, functional-style updates and efficient state sharing.
class Board
  SIZE = 8 # Board's dimensions

  # Constructs a Board from a flat array of 64 items.
  # Each item's index maps to a board position as follows:
  # 0 -> a1, 2 -> b1, ... 8 -> a2, ... 63 -> h8
  # Each item should be a Piece or nil, representing the contents of that square.
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

  # A board with all pieces set up at their starting positions
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

  # Get the piece at the given position, or nil if the position is unoccupied
  def get(position)
    index = position_to_index(position)
    @array.get(index)
  end

  # Returns an array of all pieces, with their positions, matching the criteria.
  # The result is an array of elements of the form: [piece, position]
  # If type or color is nil, that attribute is ignored.
  # Examples:
  #   All black pieces: find_pieces(color: :black)
  #   All pieces:       find_pieces
  #   White rooks:      find_pieces(type: :rook, color: :white)
  def pieces_with_positions(color: nil, type: nil)
    @array.filter_map.with_index do |piece, index|
      next if piece.nil?

      [piece, index_to_position(index)] if [nil, piece.type].include?(type) && [nil, piece.color].include?(color)
    end
  end

  # Returns an array of all pieces matching the criteria.
  # Internally delegates to #pieces_with_positions, stripping the positions.
  def find_pieces(color: nil, type: nil)
    pieces_with_positions(color: color, type: type).map(&:first)
  end

  ######## Manipulation

  def move(from, to)
    from_index = position_to_index from
    piece = @array.get from_index
    to_index = position_to_index to
    raise BoardManipulationError, 'No piece to move' if piece.nil?
    raise BoardManipulationError, 'Destination is already occupied' unless @array.get(to_index).nil?
    raise BoardManipulationError, 'Cannot move to the same position' if from == to

    Board.new(@array.set(from_index, nil).set(to_index, piece))
  end

  def remove(position)
    index = position_to_index position
    raise BoardManipulationError, 'Position is unoccupied' if get(position).nil?

    Board.new(@array.set(index, nil))
  end

  # Inserts the given piece to an empty position
  def insert(piece, position)
    index = position_to_index(position)
    raise ArgumentError, 'Not a valid piece' unless piece.is_a?(Piece)
    raise BoardManipulationError, 'Position is occupied' unless @array.get(index).nil?

    Board.new(@array.set(index, piece))
  end

  # For debugging mainly
  def to_s # rubocop:disable Metrics/MethodLength
    rows = []
    rows << '  a b c d e f g h'
    (0...SIZE).each do |row|
      row_str = "#{row + 1} "
      (0...SIZE).each do |col|
        index = position_to_index(Position.from_index(row, col))
        piece = @array.get(index)
        row_str += if piece
                     "#{piece} "
                   else
                     '. '
                   end
      end
      rows << row_str.chomp
    end
    rows << '  a b c d e f g h'
    rows.join("\n")
  end

  def ==(other)
    other.is_a?(Board) && pieces_with_positions == other.pieces_with_positions
  end

  def eql?(other)
    self == other
  end

  def hash
    # Don't use the exact same hash as #pieces_with_positions to avoid clashes
    [pieces_with_positions, 0].hash
  end

  private

  def position_to_index(position)
    raise ArgumentError unless position.is_a?(Position)
    raise InvalidPositionError unless position.valid?

    row, col = position.to_a
    (row * SIZE) + col
  end

  def index_to_position(index)
    row, col = index.divmod(SIZE)
    Position.from_index(row, col)
  end
end
