# frozen_string_literal: true

require_relative 'move_event_handler'
require_relative 'en_passant_event_handler'

HANDLER_MAP = {
  MovePieceEvent => MoveEventHandler,
  EnPassantEvent => EnPassantEventHandler
}.freeze

# Factory function for creating an event handler instance.
def event_handler_for(event, query, extras = [])
  handler_class = HANDLER_MAP[event.class]
  raise "No handler for #{event.class}" unless handler_class

  handler_class.new(query, event, extras)
end
