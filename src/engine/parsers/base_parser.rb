# frozen_string_literal: true

# Abstract base class for all chess notation parsers.
#
# A parser converts notation input into a syntactically correct event sequence.
# The output must accurately reflect the notation's syntax, but need not ensure
# that the moves are *legally valid* within the game — legality is verified later
# by the Engine.
#
# The primary interface is `#parse(notation, game_query)`, which every subclass must implement.
# `game_query` provides read-only access to the current game state, aiding in parsing decisions.
#
# Each Engine instance uses exactly one parser.
class BaseParser
  # Returns a syntactically valid event sequence for the given notation,
  # or nil if the notation cannot be parsed.
  def parse(notation, game_query)
    raise NotImplementedError, "#{self.class} must implement #parse"
  end
end
