# frozen_string_literal: true

require_relative 'movement'

# Represents a single chess piece.
class Piece
  attr_reader :color, :type
  attr_accessor :position

  def initialize(color, type, position)
    @color = color
    @type = type
    @position = position
  end

  # Returns all valid movement destinations for this piece, excluding captures.
  def moves(state: nil)
    each_potential_move(state, is_attacking: false)
  end

  # Returns all squares this piece *geometrically threatens*,
  # regardless of whether those squares are occupied or legally capturable.
  #
  # This is used for threat detection like check or pins.
  def threatened_squares(state: nil)
    each_potential_move(state, is_attacking: true)
  end

  private

  # Yields every position this piece could move to or attack, depending on mode.
  def each_potential_move(state, is_attacking:, &block)
    return enum_for(__method__, state, is_attacking: is_attacking) unless block_given?

    yielded = false
    yield_special_moves(state, is_attacking) do |move|
      yielded = true
      yield move
    end

    return if yielded

    deltas = adjust_for_color(is_attacking ? attacks_deltas : base_deltas)
    deltas.each do |delta|
      walk_deltas(delta, state, is_attacking: is_attacking, &block)
    end
  end

  # Yields any special-case movement positions defined for this piece,
  # such as pawn's initial double-step. Only applied in non-attacking context.
  def yield_special_moves(state, is_attacking)
    return enum_for(__method__, state, is_attacking) unless block_given?
    return if !movement[:special_moves] || is_attacking

    movement[:special_moves]&.each do |special|
      next unless special[:condition].call(self)

      path = adjust_for_color(special[:path])
      current = position
      path.each do |delta|
        current = position.offset(*delta)
        break if !current.valid? || state&.piece_at(current)

        yield current
      end
    end
  end

  # Walks a vector across the board and yields each step until blocked or invalid.
  def walk_deltas(delta, state, is_attacking:)
    return enum_for(__method__, delta, state, is_attacking: is_attacking) unless block_given?

    current_position = @position

    loop do
      new_move = current_position.offset(*delta)
      break unless new_move.valid?

      blocker = state&.piece_at(new_move)

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
end
