# frozen_string_literal: true

# Core components
require_relative 'game_state/game_state'
require_relative 'event_handlers/init'
require_relative 'parser'

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
    event_handler = event_handler_for(primary_event, extras, @state.query)
    result = event_handler.process
    @state.apply_events(result.events) if result.success?
    # TODO: - error checking
    notify_listeners(result)
  end

  private

  def notify_listeners(events)
    # TODO
  end
end
