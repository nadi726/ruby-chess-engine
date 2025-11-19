# frozen_string_literal: true

COLORS = %i[white black].freeze

def flip_color(color)
  case color
  when :white
    :black
  when :black
    :white
  else raise ArgumentError, "Invalid color: #{color.inspect}"
  end
end
