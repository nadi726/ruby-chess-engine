# frozen_string_literal: true

require_relative 'movement'

# Represents a single chess piece on the board.
# Contains no logic for generating moves — only represents piece state.
class Piece
  attr_reader :color, :type
  attr_accessor :position

  def initialize(color, type, position)
    @color = color
    @type = type
    @position = position
  end

  def moves
    return enum_for(:moves) unless block_given?

    if @type == :pawn
      [] # TODO
    else
      moves_deltas.each do |delta|
        get_moves(delta) { |move| yield move } # rubocop:disable Style/ExplicitBlockArgument
      end
    end
  end

  def get_moves(delta)
    return enum_for(:get_moves, delta) unless block_given?

    current_position = @position
    loop do
      new_move = current_position.offset(*delta)
      break unless new_move.valid?

      yield(new_move)
      break unless repeats_move?

      current_position = new_move
    end
  end

  def moves_deltas
    MOVEMENT[@type][:deltas]
  end

  def repeats_move?
    MOVEMENT[@type][:repeat]
  end
end
