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
def event_handler_for(primary, extras, query)
  handler_class = HANDLER_MAP[primary.class]
  raise InvalidEventSequenceError, "#{primary.class} is not an ActionEvent" unless handler_class
  raise InvalidEventSequenceError, "#{extras} is not a sequence of GameEvent objects" unless
                                    extras&.all? { it.is_a?(GameEvent) }

  handler_class.new(query, primary, extras)
end
