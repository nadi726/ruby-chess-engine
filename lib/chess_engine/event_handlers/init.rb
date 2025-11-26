# frozen_string_literal: true

require_relative 'move_event_handler'
require_relative 'en_passant_event_handler'
require_relative 'castling_event_handler'
require_relative '../errors'
require_relative '../data_definitions/events'

module ChessEngine
  # Handles chess events by dispatching them to the appropriate event handler class.
  #
  # Event handling workflow:
  # 1. The Engine provides an event representing a move or action as interpreted from user input or UI.
  # 2. The `handle` method selects the correct handler for the event type and invokes it.
  # 3. The handler validates the event against the current `Game::State`, resolves ambiguities, fills in missing data,
  #    and returns an `EventResult`:
  #    - On success: returns `EventResult.success` with a fully resolved event.
  #    - On failure: returns `EventResult.failure` with an error message.
  #
  # Entry point: `handle(event, query)`
  # Raises `InvalidEventError` if no handler exists for the event type.
  module EventHandlers
    # Individual handlers
    HANDLER_MAP = {
      MovePieceEvent => MoveEventHandler,
      EnPassantEvent => EnPassantEventHandler,
      CastlingEvent => CastlingEventHandler
    }.freeze

    module_function

    # Get the appropriate event handler and process the event
    def handle(event, query)
      handler_class = HANDLER_MAP.fetch(event.class) do
        raise InvalidEventError, "no handler for #{event}"
      end

      handler_class.call(query, event)
    end
  end
end
