# frozen_string_literal: true

require_relative 'movement'

# Represents a single chess piece.
class Piece
  attr_reader :color, :type

  def initialize(color, type)
    @color = color
    @type = type
  end

  # Returns all valid movement destinations for this piece, excluding captures.
  def moves(board, position)
    each_potential_move(board, position, is_attacking: false)
  end

  # Returns all squares this piece *geometrically threatens*,
  # regardless of whether those squares are occupied or legally capturable.
  #
  # This is used for threat detection like check or pins.
  def threatened_squares(board, position)
    each_potential_move(board, position, is_attacking: true)
  end

  private

  # Yields every position this piece could move to or attack, depending on mode.
  def each_potential_move(board, position, is_attacking:, &)
    return enum_for(__method__, board, position, is_attacking: is_attacking) unless block_given?

    yielded = false
    yield_special_moves(board, position, is_attacking) do |move|
      yielded = true
      yield move
    end

    return if yielded

    deltas = adjust_for_color(is_attacking ? attacks_deltas : base_deltas)
    deltas.each do |delta|
      walk_deltas(delta, board, position, is_attacking: is_attacking, &)
    end
  end

  # Yields any special-case movement positions defined for this piece,
  # such as pawn's initial double-step. Only applied in non-attacking context.
  def yield_special_moves(board, position, is_attacking)
    return enum_for(__method__, board, position, is_attacking) unless block_given?
    return if !movement[:special_moves] || is_attacking

    movement[:special_moves]&.each do |special|
      next unless special[:condition].call(self, position)

      path = adjust_for_color(special[:path])
      current = position
      path.each do |delta|
        current = position.offset(*delta)
        break if !current.valid? || board.get(current)

        yield current
      end
    end
  end

  # Walks a vector across the board and yields each step until blocked or invalid.
  def walk_deltas(delta, board, position, is_attacking:)
    return enum_for(__method__, delta, board, position, is_attacking: is_attacking) unless block_given?

    current_position = position

    loop do
      new_move = current_position.offset(*delta)
      break unless new_move.valid?

      blocker = board.get(new_move)

      if blocker
        yield new_move if is_attacking
        break
      else
        yield new_move
      end

      break unless movement[:repeat]

      current_position = new_move
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
    "#{color} #{type}"
  end

  # For cleaner test messages
  def inspect
    to_s
  end

  # For making Piece a value object
  def ==(other)
    other.is_a?(Piece) && color == other.color && type == other.type
  end

  def eql?(other)
    self == other
  end

  def hash
    [color, type].hash
  end

  # For Piece[color, type] syntax.
  # Makes it clearer that this is a value object, similar to Data
  def self.[](color, type)
    new(color, type)
  end
end
