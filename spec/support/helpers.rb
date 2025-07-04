# frozen_string_literal: true

require 'data_definitions/position'

# Expects a space-separated string of positions (e.g., 'a1 d6')
# And returns an array of Position objects
def parse_positions(positions)
  positions.split.map do |pos|
    Position.new(pos[0].to_sym, pos[1].to_i)
  end
end
