# frozen_string_literal: true

require_relative 'eran_formatters'

module ChessEngine
  # Namespace for all chess notation formatters.
  #
  # Formatters convert fully-populated `Events::BaseEvent` objects into a single-move notation.
  # The output must be a valid notation for a single move that accurately reflects the given event.
  #
  # It expects the event to be structurally valid:
  # all fields and nested objects must be well-formed, but the move need not be
  # legal in any particular game state.
  #
  # Each formatter should implement `.call(event)`, returning the corresponding notation,
  #  or `nil` if the event cannot be parsed.
  module Formatters
  end
end
