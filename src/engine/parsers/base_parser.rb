# frozen_string_literal: true

# Abstract base class for all chess notation parsers.
#
# A parser converts notation input into a syntactically correct `GameEvent`.
# The output must accurately reflect the provided notation, but need not ensure
# that the move is *legally valid* within the game — legality is verified later
# by the engine.
#
# The primary interface is `#parse(notation, game_query)`, which every subclass must implement.
# (`game_query` is required for aiding in parsing decisions.)
#
# Each `Engine` instance uses exactly one parser.
#
# A syntactically correct event is a `GameEvent` for which every provided field is of the expected type, or `nil`.
class BaseParser
  # Returns a syntactically valid event for the given notation,
  # or `nil` if the notation cannot be parsed.
  def parse(notation, game_query)
    raise NotImplementedError, "#{self.class} must implement #parse"
  end
end
