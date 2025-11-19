# frozen_string_literal: true

require_relative 'primitives/movement'
require_relative 'primitives/colors'
require_relative 'primitives/notation'

# Represents a single chess piece.
#
# An invalid `Piece` can be created but must not be used, as this will cause an error.
# Ensure validity with `#valid?` before usage.
class Piece
  ### Piece types
  TYPES = %i[king queen rook bishop knight pawn].freeze

  ### Promotable piece types
  PROMOTION_TYPES = %i[queen knight rook bishop].freeze

  attr_reader :color, :type

  def initialize(color, type)
    @color = color
    @type = type
  end

  # Returns all valid movement destinations for this piece, excluding captures.
  def moves(board, square)
    each_potential_move(board, square, is_attacking: false)
  end

  # Returns all squares this piece *geometrically threatens*,
  # regardless of whether those squares are occupied or legally capturable.
  #
  # This is used for threat detection like check or pins.
  def threatened_squares(board, square)
    each_potential_move(board, square, is_attacking: true)
  end

  def valid?
    COLORS.include?(color) && TYPES.include?(type)
  end

  private

  # Yields every square this piece could move to or attack, depending on mode.
  def each_potential_move(board, square, is_attacking:, &)
    return enum_for(__method__, board, square, is_attacking: is_attacking) unless block_given?

    yielded = false
    yield_special_moves(board, square, is_attacking) do |move|
      yielded = true
      yield move
    end

    return if yielded

    deltas = adjust_for_color(is_attacking ? attacks_deltas : base_deltas)
    deltas.each do |delta|
      walk_deltas(delta, board, square, is_attacking: is_attacking, &)
    end
  end

  # Yields any special-case movement squares defined for this piece,
  # such as pawn's initial double-step. Only applied in non-attacking context.
  def yield_special_moves(board, square, is_attacking)
    return enum_for(__method__, board, square, is_attacking) unless block_given?
    return if !movement[:special_moves] || is_attacking

    movement[:special_moves]&.each do |special|
      next unless special[:condition].call(self, square)

      path = adjust_for_color(special[:path])
      current = square
      path.each do |delta|
        current = square.offset(*delta)
        break if !current.valid? || board.get(current)

        yield current
      end
    end
  end

  # Walks a vector across the board and yields each step until blocked or invalid.
  def walk_deltas(delta, board, square, is_attacking:)
    return enum_for(__method__, delta, board, square, is_attacking: is_attacking) unless block_given?

    current_square = square

    loop do
      new_square = current_square.offset(*delta)
      break unless new_square.valid?

      blocker = board.get(new_square)

      if blocker
        yield new_square if is_attacking
        break
      else
        yield new_square
      end

      break unless movement[:repeat]

      current_square = new_square
    end
  end

  def movement
    MOVEMENT[@type]
  end

  def base_deltas
    movement[:moves] || []
  end

  def attacks_deltas
    movement[:attacks] || base_deltas
  end

  # Flips rank deltas for black pieces to account for orientation
  def adjust_for_color(deltas)
    @color == :black ? deltas.map { |f, r| [f, -r] } : deltas
  end

  public

  def to_s
    return "#<Piece (INVALID) color=#{color.inspect} type=#{type.inspect}>" unless valid?

    CoreNotation.piece_to_str(self)
  end

  # For cleaner test messages
  def inspect
    to_s
  end

  # For making `Piece` a value object
  def ==(other)
    other.is_a?(Piece) && color == other.color && type == other.type
  end

  def eql?(other)
    self == other
  end

  def hash
    [color, type].hash
  end

  # For `Piece[color, type]` syntax.
  # Makes it clearer that this is a value object, similar to Data
  def self.[](color, type)
    new(color, type)
  end
end
