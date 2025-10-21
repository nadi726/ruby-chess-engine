# frozen_string_literal: true

require_relative 'base_parser'
require_relative '../data_definitions/events'

# A parser that returns the input event sequence unchanged.
# Used primarily for testing, as it bypasses actual notation parsing
# and assumes the input is already valid.
class IdentityParser < BaseParser
  def parse(notation, _game_query)
    # Must be a sequence of events
    return nil unless notation.is_a?(Enumerable) && notation.all? { it.is_a?(GameEvent) }

    notation
  end
end
