# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'move_event_handler'
require_relative 'en_passant_event_handler'
require_relative '../errors'

HANDLER_MAP = {
  MovePieceEvent => MoveEventHandler,
  EnPassantEvent => EnPassantEventHandler,
  CastlingEvent => EventHandler # TODO
}.freeze

# Factory function for creating an event handler instance.
def event_handler_for(event, query)
  handler_class = HANDLER_MAP[event.class]
  raise InvalidEventError, "#{event.class} is not a GameEvent" unless handler_class

  handler_class.new(query, event)
end
