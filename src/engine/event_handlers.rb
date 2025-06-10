# frozen_string_literal: true

require_relative 'data_definitions/events'

# Validates given events, fills information if needed,
# and returns the result.
# The sole entry point is ::handle_events
class EventHandler
  EVENT_HANDLERS = {
    MovePieceEvent => :handle_move_piece,
    PromotePieceEvent => :handle_promotion,
    CastleEvent => :handle_castling,
    EnPassantEvent => :handle_en_passant
  }.freeze

  def initialize(state)
    @state = state
  end

  # Returns a hash of one of 2 forms:
  # - upon a successful result:
  #   { success: true, events: [...] }
  # Upon an unsuccessful result:
  #   { success: false, error: 'message' }
  def handle_events(primary_event, extras)
    handler = EVENT_HANDLERS.fetch(primary_event.class, nil)
    return invalid_result("Unknown event: #{primary_event}") unless handler

    result = send(handler, primary_event, extras)
    handle_extra_events(extras, result)
  end

  private

  def handle_move_piece(move_event, extras)
    MoveEventHandler.new(@state, move_event, extras).handle
  end

  def handle_promotion(promotion_event, extras)
    # TODO
    puts 'Promote piece'
    valid_result([promotion_event, *extras])
  end

  def handle_castling(castle_event, extras)
    # TODO
    puts 'castle'
    valid_result([castle_event, *extras])
  end

  def handle_en_passant(en_passant_event, _)
    EnPassantEventHandler.new(@state, en_passant_event, []).handle
  end

  def handle_extra_events(events, result) # rubocop:disable Metrics/MethodLength
    return result
    return result unless result[:success]

    events.each do |event|
      case event
      in RemovePieceEvent[]
        puts 'should not be triggered - handled by individual handler'
      in CheckEvent[color:]
        puts "#{color} is in check"
      in CheckmateEvent[color:]
        puts "#{color} is in checkmate"
      else
        return invalid_result("Unknown additional event: #{event}")
      end
    end
    # TODO: - check whether the new moves cause check or checkmate
    valid_result(result[:events] + events)
  end

  def valid_result(events)
    { success: true, events: events }
  end

  def invalid_result(message = '')
    { success: false, message: message }
  end
end

# Event handler for MovePieceEvent
class MoveEventHandler
  attr_reader :state, :main, :extras, :from_piece

  def initialize(state, main, extras)
    @state = state
    @from_piece = @state.piece_at(main.from)
    @main = MovePieceEvent.new(main.from, main.to, @from_piece) # the primary event this handler processes
    @extras = extras # optional related events (e.g. RemovePieceEvent)
  end

  def handle
    return invalid_result unless from_piece

    return handle_move_only unless valid_remove_piece_event?

    return handle_move_pawn if from_piece.type == :pawn

    handle_move_and_remove
  end

  private

  def handle_move_only
    return valid_result([main]) if @state.piece_can_move?(main.from, main.to)

    invalid_result
  end

  def handle_move_and_remove
    return invalid_result unless @state.piece_attacking?(main.from,
                                                         main.to) &&
                                 to_piece && valid_remove_piece_event?

    valid_result([main, remove_piece_event])
  end

  def handle_move_pawn
    en_passant_event_handler = EnPassantEventHandler.new(@state, EnPassantEvent.new(main.from, main.to), extras)
    en_passant_result = en_passant_event_handler.handle
    return en_passant_result if en_passant_result[:success]

    return invalid_result unless to_piece && @state.piece_attacking?(main.from, main.to)

    valid_result([main, remove_piece_event])
  end

  def remove_piece_event
    RemovePieceEvent.new(main.to, to_piece)
  end

  def valid_remove_piece_event?
    event = extras.find { _1.is_a?(RemovePieceEvent) }
    return false unless event

    [nil, main.to].include?(event.position) &&
      [nil, to_piece].include?(event.piece)
  end

  # Always use the to_piece method to access the memoized value.
  # Do not access @to_piece directly to avoid uninitialized or stale values.
  def to_piece
    @to_piece ||= state.piece_at(main.to)
  end

  def valid_result(events)
    { success: true, events: events }
  end

  def invalid_result(message = 'Invalid result for MovePieceEvent')
    { success: false, error: message }
  end
end

# Event handler for EnPassantEvent
class EnPassantEventHandler
  attr_reader :state, :main, :extras, :from_piece

  def initialize(state, main, extras)
    @state = state
    @from_piece = @state.piece_at(main.from)
    @main = main
    @extras = extras # optional related events (e.g. RemovePieceEvent)
  end

  def handle
    return invalid_result unless valid_en_passant?

    valid_result([main])
  end

  private

  def valid_en_passant?
    return false unless from_piece && from_piece.type == :pawn && main.from.distance(main.to) == [1, 1] &&
                        @state.current_pieces.include?(from_piece)

    # Get the last move and ensure it was a pawn moving two steps forward
    last_move = @state.move_history.last&.find do |move|
      move.is_a?(MovePieceEvent) && move.piece.type == :pawn &&
        move.from.distance(move.to) == [0, 2]
    end
    return false unless last_move

    # is adjacent
    last_move.to.distance(from_piece.position) == [1, 0]
  end

  def valid_result(events)
    { success: true, events: events }
  end

  def invalid_result(message = 'Invalid result for EnPassantEvent')
    { success: false, error: message }
  end
end
