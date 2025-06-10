# frozen_string_literal: true

require_relative 'game_state'
require_relative 'parser'
require_relative 'event_handlers'
require_relative 'data_definitions/events'

# Handles the game.
# - Keeps track of the state of the game and the pieces on the board
# - consumes moves - both regular and special moves.
# - Sends relevant information about the game to the "listener"
# (most likely, the UI or game "handler" - those parts are not yet planned)
class Engine
  def initialize
    @state = GameState.new
    @parser = nil # TODO
    @listeners = []
    @event_handler = EventHandler.new(@state)
  end

  def add_listener(listener)
    @listeners << listener unless @listeners.include?(listener)
  end

  def remove_listener(listener)
    @listeners.delete(listener)
  end

  def consume_notation(str)
    # TODO: - implement notation parser
  end

  def consume_event(events)
    # Additional events supply information not in the primary event
    # For example - that a piece has to be removed, or that there is a checkmate
    # This is the kind of information that could be provided by chess notation
    primary_event, *extras = events
    result = @event_handler.handle_events(primary_event, extras)
    @state.apply_events(result[:events]) if result[:success]
    # TODO: - error checking
    notify_listeners(result)
  end

  private

  def notify_listeners(events)
    # TODO
  end
end
