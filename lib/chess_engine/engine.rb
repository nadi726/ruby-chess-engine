# frozen_string_literal: true

# Core components
require_relative 'data_definitions/position'
require_relative 'game/init'
require_relative 'event_handlers/init'
require_relative 'parsers/init'

module ChessEngine
  # The `Engine` is the central coordinator and interpreter of the chess game.
  #
  # It interprets structured input (chess notation) and translates it into concrete
  # state transitions, producing `GameUpdate` objects and notifying registered listeners.
  #
  # The engine is responsible for a single game session at a time.
  # On initialization, you must choose the notation parser the engine will use (or use the default one).
  #
  # After initializing an engine, you must begin a session either by:
  # - starting a new game with `#new_game`
  # - loading a game from existing state with `#from_fen`
  #
  # The game can be exported at any point with `#to_fen`.
  #
  # Clients advance the engine through two mechanisms:
  # - By playing a turn, via the `#play_turn` method.
  # - By attempting a game-ending action: offering, accepting, claiming a draw, or by resigning.
  #   Those actions are triggered by `#offer_draw`, `#accept_draw`, `#claim_draw` and `#resign` respectively.
  #
  # To observe game progress, clients can:
  # - Register as listeners and implement `#on_game_update(game_update)` to get turn-by-turn updates,
  #   as well as error messages(a `GameUpdate.failure` object) for an invalid client operation.
  # - call the `#last_update` method to get the last game update status.
  class Engine # rubocop:disable Metrics/ClassLength
    DEFAULT_PARSER = Parsers::ERANParser

    def initialize(default_parser: DEFAULT_PARSER)
      raise ArgumentError, "Not a valid `Parser`: #{default_parser}" unless default_parser.respond_to?(:call)

      @listeners = []
      @default_parser = default_parser
    end

    def add_listener(listener)
      @listeners << listener unless @listeners.include?(listener)
    end

    def remove_listener(listener) = @listeners.delete(listener)

    def default_parser(parser)
      raise ArgumentError, "Not a valid `Parser`: #{default_parser}" unless parser.respond_to?(:call)

      @default_parser = parser
    end

    # Starts a new game. Resets the game's state and starts a new session.
    def new_game
      load_game_state(Game::State.start)
    end

    def from_fen(fen_str)
      position = Position.from_fen(fen_str)
      load_game_state(Game::State.load(position))
    end

    def to_fen
      @state.position.to_fen
    end

    # The last update that was made.
    # Useful for directly retrieving the most recent `GameUpdate`,
    # allowing inspection of game state changes without engaging with the listener model.
    attr_reader :last_update

    # Plays one side’s turn.
    #
    # Parses the given notation, interprets the corresponding event,
    # updates the engine’s state, and notifies listeners with a `GameUpdate`.
    #
    # Returns a corresponding `GameUpdate`.
    def play_turn(notation, parser = @default_parser)
      result = interpret_turn(notation, parser)
      result.success? ? update_game(**result.success_attributes) : notify_listeners(result)
      result
    end

    # Registers a draw offer from the current player.
    # Although FIDE technically allows offering a draw at any point,
    # the engine enforces that only the current player may do so,
    # which results in a simpler interface and therefore makes more sense from an engine perspective.
    def offer_draw
      failure = detect_general_failure || (GameUpdate.failure(:draw_offer_not_allowed) if @offered_draw)

      failure ? notify_listeners(failure) : update_game(offered_draw: query.position.current_color)
    end

    # Accepts a pending draw offer from the opponent and ends the game.
    # Does nothing if no offer exists.
    def accept_draw
      invalid_offer = @offered_draw.nil? || @offered_draw == query&.position&.current_color
      failure = detect_general_failure || (GameUpdate.failure(:draw_accept_not_allowed) if invalid_offer)

      failure ? notify_listeners(failure) : update_game(endgame_status: GameOutcome[:draw, :agreement])
    end

    # Claims a draw by rule (50-move rule or repetition) if eligible.
    # Does nothing if the claim is invalid.
    def claim_draw # rubocop:disable Metrics/CyclomaticComplexity
      eligible_cause = if query&.threefold_repetition? then :threefold_repetition
                       elsif query&.fifty_move_rule? then :fifty_move
                       end
      failure = detect_general_failure || (GameUpdate.failure(:draw_claim_not_allowed) unless eligible_cause)

      failure ? notify_listeners(failure) : update_game(endgame_status: GameOutcome[:draw, eligible_cause])
    end

    # Resign and end the game immediately.
    def resign
      failure = detect_general_failure
      winner = query&.position&.other_color # For non-failure

      failure ? notify_listeners(failure) : update_game(endgame_status: GameOutcome[winner, :resignation])
    end

    private

    # Interprets a move notation through all internal processing stages.
    # If valid, advances the engine state; Returns a `GameUpdate`.
    def interpret_turn(notation, parser)
      failure = detect_general_failure
      return failure unless failure.nil?

      event = parser.call(notation, @state.query)
      return GameUpdate.failure(:invalid_notation) unless event

      interpret_event(event)
    rescue InvariantViolationError => e
      raise InternalEngineError, "The engine encountered a problem: #{e}"
    end

    # Executes a given event.
    #
    # On success:
    # - Applies event to the current `Game::State`
    # - Returns a `GameUpdate.success` with updated fields
    #
    # On failure:
    # - Returns a `GameUpdate.failure(:invalid_event)`
    def interpret_event(event)
      result = EventHandlers.handle(event, @state.query)
      return GameUpdate.failure(:invalid_event) if result.failure?

      state = @state.apply_event(result.event)
      GameUpdate.success(
        event: result.event,
        state: state,
        endgame_status: detect_endgame_status(state.query),
        # Clear draw offer if the opponent just moved without accepting
        offered_draw: state.position.current_color == @offered_draw ? nil : @offered_draw,
        session: @session.current
      )
    end

    # Updates the engine with the provided fields:
    # - updates the specified subset of instance variables related to current game session
    # - notifies listeners of the update and returns it
    def update_game(state: :not_provided, endgame_status: :not_provided, offered_draw: :not_provided,
                    session: :not_provided, event: :not_provided)
      @state = state unless state == :not_provided
      @endgame_status = endgame_status unless endgame_status == :not_provided
      @offered_draw = offered_draw unless offered_draw == :not_provided
      @session = session unless session == :not_provided
      @event = event unless event == :not_provided
      @last_update = GameUpdate.success(event: @event, state: @state, endgame_status: @endgame_status,
                                        offered_draw: @offered_draw, session: @session)
      notify_listeners(@last_update)
      @last_update
    end

    def notify_listeners(game_update)
      @listeners.each do |listener|
        listener.on_game_update(game_update)
      end
      game_update
    end

    # Checks the given state for checkmate or automatic draw conditions.
    # The provided `Game::Query` should reflect the latest position after a move,
    # so this method always returns the endgame status resulting from the most recent update.
    # Returns a `GameOutcome` object if the game has ended, otherwise returns nil
    def detect_endgame_status(query)
      return GameOutcome[query.position.other_color, :checkmate] if query.in_checkmate?

      cause = if query.stalemate? then :stalemate
              elsif query.insufficient_material? then :insufficient_material
              elsif query.fivefold_repetition? then :fivefold_repetition
              end

      return nil if cause.nil?

      GameOutcome[:draw, cause]
    end

    # General detection for invalid client action
    def detect_general_failure
      return GameUpdate.failure(:no_ongoing_session) unless @session
      return GameUpdate.failure(:game_already_ended) if @endgame_status

      nil
    end

    # Convenience accessor
    def query = @state&.query

    # Starts a new game session with the given state.
    def load_game_state(state, offered_draw: nil)
      update_game(
        state: state,
        endgame_status: detect_endgame_status(state.query),
        offered_draw: offered_draw,
        event: nil,
        session: @session.nil? ? SessionInfo.started(0) : @session.next
      )
    end
  end

  # Represents the outcome of a change in the state of the game, like playing a turn or accepting a draw.
  #
  # On success, it contains:
  # - The event that describes what happened.
  # - The full `Game::State` and `Game::Query` for inspection.
  # - The current endgame status (if any).
  # - The current draw offer status.
  # - Metadata about the current game session.
  #
  # On failure, contains only `error`, which is one of:
  # - `:invalid_notation`
  # - `:invalid_event`
  # - `:game_already_ended`
  # - `:no_ongoing_session`
  # - `:draw_offer_not_allowed`
  # - `:draw_accept_not_allowed`
  # - `:draw_claim_not_allowed`
  #
  # Note: `error` may later be replaced with a structured object to support
  # more detailed error handling.
  #
  # Typically, clients should rely on the event sequence and status fields;
  # direct access to `Game::Query` is for specialized use cases.
  GameUpdate = Data.define(:event, :state, :endgame_status, :offered_draw, :session, :error) do
    def success? = error.nil?
    def failure? = !success?

    def self.success(event:, state:, endgame_status:, offered_draw:, session:)
      new(event, state, endgame_status, offered_draw, session, nil)
    end

    def self.failure(error)
      new(nil, nil, nil, nil, nil, error)
    end

    # A successful result has no `error` field
    def success_attributes
      to_h.except(:error)
    end

    # A failed result has only an `error` field
    def failure_attributes
      { error: error }
    end

    def game_ended? = !endgame_status.nil?
    def in_check? = game_query.in_check?
    def can_draw? = game_query.can_draw?

    def game_query = state.query
    def position = state.position
    def board = position.board
    def current_color = position.current_color

    private_class_method :new # enforces use of factories
  end

  # Metadata about the current game session
  SessionInfo = Data.define(:id, :new?) do
    def self.ongoing(id) = new(id, false)
    def self.started(id) = new(id, true)
    def next = self.class.started(id + 1)
    def current = self.class.ongoing(id)
  end

  # winner is one of: :white, :black, :draw
  # cause is one of: :checkmate, :resignation, :agreement, :stalemate, :insufficient_material, :fivefold_repetition,
  #                  :threefold_repetition, :fifty_move
  GameOutcome = Data.define(:winner, :cause)
end
