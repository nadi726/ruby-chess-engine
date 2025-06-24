# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'en_passant_event_handler'
require_relative 'move_event_handler'

# Validates given events, fills information if needed,
# and returns the result.
# The sole entry point is ::handle_events
class EventHandler
  EVENT_HANDLERS = {
    MovePieceEvent => :handle_move_piece,
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
    handler = EVENT_HANDLERS[primary_event.class]
    return invalid_result("Unknown event: #{primary_event}") unless handler

    result = send(handler, primary_event, extras)
    handle_extra_events(extras, result)
  end

  private

  def handle_move_piece(move_event, extras)
    MoveEventHandler.new(@state, move_event, extras).handle
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
    return result unless result[:success] # rubocop:disable Lint/UnreachableCode

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
    { success: false, error: message }
  end
end
