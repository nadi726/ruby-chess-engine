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
    # TODO
  end
end
