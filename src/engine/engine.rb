# frozen_string_literal: true

# Core components
require_relative 'game_state/game_state'
require_relative 'event_handlers/init'
require_relative 'parsers/identity_parser'

# The Engine is the central coordinator and interpreter of the chess game.
#
# It interprets structured input (chess notation) and translates it into concrete
# state transitions, producing `GameUpdate` objects and notifying registered listeners.
#
# Each engine is responsible for a single game, and uses a single `Parser` for parsing notation.
# `#initialize` starts a new game.
# Use `::from_fen` to import a game to the engine, and `#to_fen` to export a game from an engine.
#
# Clients advance the engine through two mechanisms:
# - By playing a turn, via the `#play_turn` method.
# - By attempting a game-ending action: offering, accepting, claiming a draw, or by resigning.
#   Those actions are triggered by `#offer_draw`, `#accept_draw`, `#claim_draw` and `#resign` respectively.
#
# To observe game progress, clients can:
# - Register as listeners and implement `#on_game_update(game_update)` to get turn-by-turn updates
# - call the `#query` methods to get the current game snapshot
class Engine # rubocop:disable Metrics/ClassLength
  def initialize(parser = nil)
    @state = GameState.new
    @parser = parser || IdentityParser.new
    @endgame_status = nil # nil for an ongoing game, `GameOutcome` for a concluded game
    @offered_draw = nil # color of whoever currently offers a draw, or nil if no draw is being offered
    @listeners = []
  end

  def self.from_fen(fen_str, parser: nil)
    # TODO
  end

  def to_fen
    # TODO
  end

  def add_listener(listener)
    @listeners << listener unless @listeners.include?(listener)
  end

  def remove_listener(listener) = @listeners.delete(listener)

  def query = @state.query

  # Plays one side’s turn.
  #
  # Parses the given notation, interprets the corresponding events,
  # updates the engine’s state, and notifies listeners with a `GameUpdate`.
  #
  # Returns a corresponding `GameUpdate`.
  def play_turn(notation)
    result = interpret_turn notation
    notify_listeners result
    result
  end

  # Registers a draw offer from the current player.
  # Although FIDE technically allows offering a draw at any point,
  # the engine enforces that only the current player may do so,
  # which results in a simpler interface and therefore makes more sense from an engine perspective.
  def offer_draw
    return if @endgame_status

    @offered_draw = query.position.current_color
  end

  # Accepts a pending draw offer from the opponent and ends the game.
  # Does nothing if no offer exists.
  def accept_draw
    return if @endgame_status
    return unless @offered_draw && @offered_draw != query.position.current_color

    end_game(GameOutcome[:draw, :agreement])
  end

  # Claims a draw by rule (50-move rule or repetition) if eligible.
  # Does nothing if the claim is invalid.
  def claim_draw
    return if @endgame_status
    return unless query.can_draw?

    cause = query.threefold_repetition? ? :threefold_repetition : :fifty_move
    end_game(GameOutcome[:draw, cause])
  end

  # Resign and end the game immediately.
  def resign
    return if @endgame_status

    winner = query.position.other_color
    end_game(GameOutcome[winner, :resignation])
  end

  private

  # Interprets a move notation through all internal processing stages.
  # If valid, advances the engine state; Returns a `GameUpdate`.
  def interpret_turn(notation)
    return GameUpdate.failure(:game_already_ended) if @endgame_status

    events = parse_notation(notation)
    return GameUpdate.failure(:invalid_notation) unless events

    interpret_events(events)
  rescue InvariantViolationError => e
    raise InternalEngineError, "The engine encountered a problem: #{e}"
  end

  # Parses notation into a sequence of abstract chess events.
  #
  # The resulting event sequence is not necessarily valid in game context,
  # only syntactically valid. Returns nil if parsing fails.
  def parse_notation(notation)
    @parser.parse(notation, @state.query)
  end

  # Executes a given event sequence.
  #
  # On success:
  # - Applies events to the current `GameState`
  # - Updates endgame and offered draw status
  # - Returns a `GameUpdate.success`
  #
  # On failure:
  # - Returns a `GameUpdate.failure(:invalid_event_sequence)`
  def interpret_events(events) # rubocop:disable Metrics/MethodLength
    primary_event, *extras = events
    event_handler = event_handler_for(primary_event, extras, @state.query)
    result = event_handler.process
    return GameUpdate.failure(:invalid_event_sequence) if result.failure?

    @state = @state.apply_events(result.events)
    # Clear draw offer if the opponent just moved without accepting
    @offered_draw = nil if @state.position.current_color == @offered_draw
    @endgame_status = detect_endgame_status

    GameUpdate.success(
      events: result.events,
      game_query: @state.query,
      in_check: @state.query.in_check?,
      endgame_status: @endgame_status
    )
  end

  def notify_listeners(game_update)
    @listeners.each do |listener|
      listener.on_game_update(game_update)
    end
  end

  # Checks the current state for checkmate or automatic draw conditions.
  # Returns a `GameOutcome` object if the game has ended, otherwise returns nil
  def detect_endgame_status
    return GameOutcome[query.position.other_color, :checkmate] if query.in_checkmate?
    return unless query.must_draw?

    cause = if query.stalemate?
              :stalemate
            elsif query.insufficient_material?
              :insufficient_material
            else
              :fivefold_repetition # TODO: - not implemented yet
            end
    GameOutcome[:draw, cause]
  end

  # Updates endgame status, notifies listeners, and returns the corresponding `GameUpdate`.
  # Only used for explicit game-ending actions (resign, accept_draw, claim_draw).
  def end_game(game_outcome)
    @endgame_status = game_outcome
    game_update = GameUpdate.success(
      events: [],
      game_query: query,
      in_check: query.in_check?,
      endgame_status: game_outcome
    )
    notify_listeners(game_update)
    game_update
  end

  # Allows controlled creation from arbitrary state.
  # Used by test suites and FEN importers only.
  private_class_method def self.__from_raw_state(state, parser: nil, endgame_status: nil, offered_draw: nil)
    engine = allocate # skips initialize
    engine.instance_variable_set(:@state, state)
    engine.instance_variable_set(:@parser, parser)
    engine.instance_variable_set(:@endgame_status, endgame_status)
    engine.instance_variable_set(:@offered_draw, offered_draw)
    engine.instance_variable_set(:@listeners, [])
    engine
  end
end

# Represents the outcome of a change in the state of the game, like playing a turn or accepting a draw.
#
# On success, it contains:
# - The event sequence that describes what happened.
# - Whether the current player is in check.
# - The current endgame status (if any).
# - The full `GameQuery` for advanced inspection.
#
# On failure, only `error` is set (one of :invalid_notation, :invalid_event_sequence, :game_already_ended).
#
# Note: `error` may later be replaced with a structured object to support
# more detailed error handling.
#
# Typically, clients should rely on the event sequence and status fields;
# direct access to `GameQuery` is for specialized use cases.
GameUpdate = Data.define(:events, :game_query, :in_check, :endgame_status, :error) do
  def success? = error.nil?
  def failure? = !success?
  def game_ended? = !endgame_status.nil?

  def self.success(events:, game_query:, in_check:, endgame_status:)
    new(events.freeze, game_query, in_check, endgame_status, nil)
  end

  def self.failure(error)
    new(nil, nil, nil, nil, error)
  end

  private_class_method :new # enforces use of factories
end

# winner is one of: :white, :black, :draw
# cause is one of: :checkmate, :resignation, :agreement, :stalemate, :insufficient_material, :fivefold_repetition,
#                  :threefold_repetition, :fifty_move
GameOutcome = Data.define(:winner, :cause)
