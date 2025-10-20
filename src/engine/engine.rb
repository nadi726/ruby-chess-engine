# frozen_string_literal: true

# Core components
require_relative 'game_state/game_state'
require_relative 'event_handlers/init'
require_relative 'parser'

# The Engine is the central coordinator and interpreter of the chess game.
#
# It interprets structured input (chess notation) and translates it into concrete
# state transitions, producing TurnResult objects and notifying registered listeners.
#
# Clients interact with the engine through two mechanisms:
# - `#play_turn`: interprets a move in chess notation and advances the game.
# - `#attempt_draw`: manages the draw-attempt system (mutual agreement or claim-based draws).
#
# To observe game progress, clients must register as listeners and implement:
#   `#on_engine_update(turn_result)`
# which is called after each turn or state change.
class Engine
  def initialize
    @state = GameState.new
    @parser = nil # placeholder for the notation parser - TODO
    @endgame_status = nil # one of - nil, :white_checkmate, :black_checkmate, :draw
    @draw_request = nil # one of - nil, :white, :black
    @listeners = []
  end

  def add_listener(listener)
    @listeners << listener unless @listeners.include?(listener)
  end

  def remove_listener(listener)
    @listeners.delete(listener)
  end

  # Plays one side’s turn.
  #
  # Parses the given notation, interprets the corresponding events,
  # updates the engine’s state, and notifies listeners with a TurnResult.
  #
  # Returns a corresponding TurnResult.
  def play_turn(notation)
    result = interpret_turn notation
    notify_listeners result
    result
  end

  # Handles draw offers and rule-based draw claims.
  #
  # A draw is triggered if:
  # - The requesting player is eligible to claim a draw (threefold repetition or fifty-move rule)
  # - Both players have offered a draw.
  #
  # Notifies listeners if the game ends in a draw.
  # Returns a TurnResult when a draw occurs, or nil otherwise.
  def attempt_draw(color) # rubocop:disable Metrics/MethodLength
    # Check whether the request makes a draw
    is_mutual_draw = @draw_request == @state.data.other_color
    is_forced_draw = color == @state.data.current_color && @state.query.can_draw?
    if is_mutual_draw || is_forced_draw
      @endgame_status = :draw
      turn_result = TurnResult.success(
        events: [],
        game_query: @state.query,
        in_check: nil,
        endgame_status: :draw
      )
      notify_listeners(turn_result)
      return turn_result
    end

    # otherwise, set a draw request for the turn
    @draw_request = color
  end

  private

  # Interprets a move notation through all internal processing stages.
  # If valid, advances the engine state; Returns a TurnResult.
  def interpret_turn(notation)
    return TurnResult.failure(:game_ended) if @endgame_status

    events = parse_notation(notation)
    return TurnResult.failure(:invalid_notation) unless events

    interpret_events(events)
  end

  # Parses notation into a sequence of abstract chess events.
  #
  # The resulting event sequence is not necessarily valid in game context,
  # only syntactically valid. Returns nil if parsing fails.
  def parse_notation(notation)
    # TODO: - implement notation parser
  end

  # Executes a given event sequence.
  #
  # On success:
  # - Applies events to the current GameState
  # - Updates endgame and draw status
  # - Returns a TurnResult.success
  #
  # On failure:
  # - Returns a TurnResult.failure(:invalid_event_sequence)
  def interpret_events(events) # rubocop:disable Metrics/MethodLength
    primary_event, *extras = events
    event_handler = event_handler_for(primary_event, extras, @state.query)
    result = event_handler.process
    return TurnResult.failure(:invalid_event_sequence) if result.failure?

    @state = @state.apply_events(result.events)
    @endgame_status = detect_endgame_status
    @draw_request = nil if @state.data.current_color == :black # reset draw request on turn's end

    TurnResult.success(
      events: result.events,
      game_query: @state.query,
      in_check: @state.query.in_check?,
      endgame_status: @endgame_status
    )
  end

  def notify_listeners(turn_result)
    @listeners.each do |listener|
      listener.on_engine_update(turn_result)
    end
  end

  # Checks the current GameState for checkmate or draw conditions.
  # Returns one of :white_checkmate, :black_checkmate, :draw, or nil.
  def detect_endgame_status
    query = @state.query
    if query.checkmate?(:white)
      :white_checkmate
    elsif query.checkmate?(:black)
      :black_checkmate
    elsif query.must_draw?
      :draw
    end
  end
end

# Represents the outcome of interpreting a single turn.
#
# On success, it contains:
# - The event sequence that describes what happened.
# - Whether the current player is in check.
# - The current endgame status (if any).
# - The full GameQuery for advanced inspection.
#
# On failure, only `error` is set (one of :invalid_notation, :invalid_event_sequence, :game_ended).
#
# Note: `error` may later be replaced with a structured object to support
# more detailed error handling.
#
# Typically, clients should rely on the event sequence and status fields;
# direct access to GameQuery is for specialized use cases.
TurnResult = Data.define(:events, :game_query, :in_check, :endgame_status, :error) do
  def success? = error.nil?
  def failure? = !success?
  def game_ended? = !endgame_status.nil?

  def self.success(events:, game_query:, in_check:, endgame_status:)
    new(events.freeze, game_query, in_check, endgame_status, nil)
  end

  def self.failure(error:)
    new(nil, nil, nil, nil, error)
  end

  private_class_method :new # enforces use of factories
end
