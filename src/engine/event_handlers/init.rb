# frozen_string_literal: true

require_relative 'move_event_handler'
require_relative 'en_passant_event_handler'
require_relative 'castling_event_handler'
require_relative '../errors'
require_relative '../data_definitions/events'

HANDLER_MAP = {
  MovePieceEvent => MoveEventHandler,
  EnPassantEvent => EnPassantEventHandler,
  CastlingEvent => CastlingEventHandler
}.freeze

# Get the appropriate event handler and process the event
def handle_event(event, query)
  handler_class = HANDLER_MAP.fetch(event.class) do
    raise InvalidEventError, "no handler for #{event}"
  end

  handler_class.call(query, event)
end
