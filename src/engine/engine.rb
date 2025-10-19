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

  def consume_notation(str)
    # TODO: - implement notation parser
    # return error when @endgame_status is not nil
  end

  def consume_event(events)
    primary_event, *extras = events
    event_handler = event_handler_for(primary_event, extras, @state.query)
    result = event_handler.process

    @state = @state.apply_events(result.events) if result.success?
    @endgame_status = detect_endgame_status
    @draw_request = nil if @state.data.current_color == :black # reset draw request on turn's end

    # TODO: - error checking
    result = TurnResult.success # TODO: - fill this
    notify_listeners(result)
  end

  # Handles all draw attempts.
  # Triggers a draw when:
  # - The requesting player is eligible to claim a draw (threefold repetition or fifty-move rule)
  # - Both players have offered a draw
  def attempt_draw(color) # rubocop:disable Metrics/MethodLength
    # Check whether the request makes a draw
    is_mutual_draw = @draw_request == @state.data.other_color
    is_forced_draw = color == @state.data.current_color && @state.query.can_draw?
    if is_mutual_draw || is_forced_draw
      @endgame_status = :draw
      turn_result = TurnResult.success(
        events: [],
        game_query: @state.query,
        check_status: nil,
        endgame_status: :draw
      )
      notify_listeners(turn_result)
      return
    end

    # otherwise, set a draw request for the turn
    @draw_request = color
  end

  private

  def notify_listeners(turn_result)
    @listeners.each do |listener|
      listener.on_engine_call(turn_result)
    end
  end

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

# Represents the outcome of processing a single-side turn.
#
# - On success: contains all information about the the turn's consequences
#   and the current state of the game
# - On failure: contains an error message (`error`), and everything else is nil
#
# error is one of:
# :invalid_notation, :invalid_event_sequence, :game_ended, to-be-determined-symbols
#
# Note: The `error` field is currently a symbol, but may be replaced
#       with a structured error object in the future to support programmatic handling.
#
# The "standard interface" of a succesful result is the event sequence as well as check and endgame status.
# Clients should not need to access game_query unless they require specialized information.
# (Should only happen either for very specific kinds of information or when a client processes information
# in an unusual way - such as by not relying on event sequence)
TurnResult = Data.define(:events, :game_query, :check_status, :endgame_status, :error) do
  def success? = error.nil?
  def failure? = !success?
  def game_ended? = !endgame_status.nil?

  def self.success(events:, game_query:, check_status:, endgame_status:)
    new(events.freeze, game_query, check_status, endgame_status, nil)
  end

  def self.failure(error:)
    new(nil, nil, nil, nil, error)
  end

  private_class_method :new # enforces use of factories
end
