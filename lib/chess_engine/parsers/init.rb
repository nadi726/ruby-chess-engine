# frozen_string_literal: true

require_relative 'eran_parser'
require_relative 'identity_parser'

module ChessEngine
  # Namespace for all chess notation parsers.
  #
  # Parsers convert notation input into syntactically correct `Events::BaseEvent` objects.
  # The output must accurately reflect the provided notation, but need not ensure
  # that the move is *legally valid* within the game — legality is verified later
  # by the engine.
  #
  # Each parser should implement `.call(notation, game_query)`, returning a syntactically valid event
  # for the given notation, or `nil` if the notation cannot be parsed.
  #
  # A syntactically correct event is a `Events::BaseEvent` for which every provided field is of the expected type,
  # or `nil`.
  module Parsers
  end
end
