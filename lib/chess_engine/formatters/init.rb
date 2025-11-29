# frozen_string_literal: true

require_relative 'eran_formatters'

module ChessEngine
  # Namespace for all chess notation formatters.
  #
  # Formatters convert fully-populated `Events::BaseEvent` objects into a single-move notation.
  # The output must be a valid notation for a single move that accurately reflects the given event.
  #
  # It expects the event to be structurally valid:
  # all fields and nested objects must be well-formed.
  # Certain formatters and notations might also require the move to be valid under the game context.
  #
  # Each formatter should implement `.call(event, game_query)`, returning the corresponding notation,
  #  or `nil` if the event cannot be parsed.
  module Formatters
  end
end
