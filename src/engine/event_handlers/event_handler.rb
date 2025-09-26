# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'event_result'

# Base class for all event handlers.
#
# Each handler validates a main event (and any accompanying extras)
# against the current game state. It either produces a fully resolved
# event list (suitable for application to the GameState), or returns an error.
#
# This class defines shared behavior and lifecycle:
# 1. `#handle` — implemented by subclasses, checks and expands the event sequence.
# 2. `#post_process` — generic logic applied to all valid results (e.g. check status).
#
# Subclasses must implement `#handle`.
# Consumers should only call `#process`.
class EventHandler
  attr_reader :query, :main, :extras, :from_piece

  def initialize(query, main, extras)
    @query = query
    @from_piece = @query.board.get(main.from)
    @main = main
    @extras = extras
  end

  # Primary entry point.
  # Validates and completes the event sequence, returning an EventResult.
  def process
    result = validate_and_resolve
    return result if result.failure?

    post_process(result.events)
  end

  private

  # To be implemented by subclasses.
  # Validates and resolves the main event (plus any extras) into a fully
  # determined sequence of low-level events suitable for GameState application.
  # Returns an EventResult with either the finalized sequence or an error.
  def validate_and_resolve
    raise NotImplementedError
  end

  # Common post-processing logic, applied to all valid results.
  # (e.g., flagging check or checkmate events, enforcing turn-based constraints, etc.)
  def post_process(events)
    return invalid_result if next_turn_in_check?(events)

    valid_result events # Placeholder
  end

  def next_turn_in_check?(events)
    new_query = query.state.apply_events(events).query
    new_query.in_check?(query.data.current_color)
  end

  def valid_result(events)
    EventResult.success events
  end

  def invalid_result(error = '')
    EventResult.failure error
  end

  # Always use the to_piece method to access the memoized value.
  # Do not access @to_piece directly to avoid uninitialized or stale values.
  def to_piece
    @to_piece ||= query.board.get(main.to)
  end
end
