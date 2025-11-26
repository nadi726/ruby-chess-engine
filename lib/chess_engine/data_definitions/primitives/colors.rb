# frozen_string_literal: true

module ChessEngine
  # Defines player colors and helpers.
  module Colors
    COLORS = %i[white black].freeze

    module_function

    # Returns the opposite color (:white <-> :black)
    def flip(color)
      case color
      when :white then :black
      when :black then :white
      else raise ArgumentError, "Invalid color: #{color.inspect}"
      end
    end

    alias other flip

    def valid?(color) = COLORS.include?(color)
    def each(&) = COLORS.each(&)
    def to_s(color) = color.to_s.capitalize
  end
end
