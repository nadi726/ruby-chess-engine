# frozen_string_literal: true

require_relative '../data_definitions/events'

# Base class for all event handlers.
#
# Each handler validates an event against the current game state.
# It either produces a fully resolved event (suitable for application to the `GameState`), or returns an error.
#
# Handlers are implemented as classes for convenience (shared helpers, instance context),
# but their public API is procedural:
# `.call(query, event)` runs the handler and returns an `EventResult`.
#
# Subclasses must implement `#resolve`.
class EventHandler
  attr_reader :query, :event

  def initialize(query, event)
    @query = query
    @event = event
  end

  # Primary entry point.

  def self.call(query, event)
    new(query, event).call
  end

  # Validates and completes the event, returning an `EventResult`.
  # Clients should use the class-level `.call` instead.
  def call
    result = resolve
    return result if result.failure?

    post_process(result.event)
  end

  private

  # To be implemented by subclasses.
  # Validates and resolves the given `GameEvent` into a full, valid event, suitable for `GameState` application.
  # Returns an `EventResult` with either the finalized event or an error.
  def resolve
    raise NotImplementedError
  end

  # Common post-processing logic, applied to all valid results.
  # (e.g., flagging check or checkmate events, enforcing turn-based constraints, etc.)
  def post_process(event)
    return failure if next_turn_in_check?(event)

    success(event) # Placeholder
  end

  def next_turn_in_check?(event)
    new_query = query.state.apply_event(event).query
    new_query.in_check?(position.current_color)
  end

  ### Helpers for subclasses

  # Runs a series of resolution steps in order.
  # Stops when out of steps, or when result doesn't match the specified condition.
  # By default, the condition is for `result` to be succesful.
  # You can set custom stop conditions for specific steps using `stop_conditions`.
  #
  # `steps`: a series of method names on `self` to execute. Each step takes the event and returns an `EventResult`.
  # `stop_conditions`: a hash where each key is a step and the value is a condition lambda.
  def run_resolution_pipeline(*steps, **stop_conditions)
    default_condition = lambda(&:success?)
    result = success(event)
    steps.each do |step|
      result = send(step, result.event)
      condition = stop_conditions.fetch(step, default_condition)
      return result unless condition.call(result)
    end
    result
  end

  def success(event)
    EventResult.success(event)
  end

  def failure(msg = '')
    msg = "Message: #{msg}" unless msg.empty?
    EventResult.failure("Invalid result for #{event.inspect}. #{msg}")
  end

  # Useful accessors
  def board = @query.board
  def position = query.position
  def current_color = position.current_color
  def other_color = position.other_color
end

# Represents the outcome of processing a chess event.
#
# - On success: contains the finalized event, and `error` is nil.
# - On failure: contains an error message (`error`), and `event` is nil.
EventResult = Data.define(:event, :error) do
  def success? = error.nil?
  def failure? = !success?

  def self.success(event) = new(event, nil)
  def self.failure(error) = new(nil, error)

  private_class_method :new # enforces use of factories
end
