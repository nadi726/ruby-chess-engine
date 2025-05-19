# frozen_string_literal: true

require_relative 'game_state'
require_relative 'parser'
require_relative 'data_definitions/events'

# Handles the game.
# - Keeps track of the state of the game and the pieces on the board
# - consumes moves - both regular and special moves.
# - Sends relevant information about the game to the "listener"
# (most likely, the UI or game "handler" - those parts are not yet planned)
class Engine
  EVENT_HANDLERS = {
    MovePieceEvent => :handle_move_piece,
    PromotePieceEvent => :handle_promotion,
    CastleEvent => :handle_castling,
    EnPassantEvent => :handle_en_passant
  }.freeze

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

    handler = EVENT_HANDLERS.fetch(primary_event.class)
    send(handler, primary_event, extras)

    handle_extra_events(extras)
  end

  private

  def send_events(events)
    # TODO
  end

  def handle_move_piece(move_event, extras)
    puts "Move a piece from #{move_event.from} to #{move_event.to}."
    return unless extras.include?(RemovePieceEvent)

    puts 'Capture piece'
    # TODO
    if en_passant?(primary_event)
      en_passant
    else
      # TODO: - Determine where enpassant capture is

    end
  end

  def handle_promotion(promotion_event, extras)
    # TODO
    puts 'Promote piece'
  end

  def handle_castling(castle_event, extras)
    # TODO
    puts 'castle'
  end

  def handle_en_passant(en_passant_event, extras)
    # TODO
    puts 'en passant'
  end

  def handle_extra_events(events)
    events.each do |event|
      case event
      in RemovePieceEvent[]
        puts 'should not be triggered - handled by individual handler'
      in CheckEvent[color:]
        puts "#{color} is in check"
      in CheckmateEvent[color:]
        puts "#{color} is in checkmate"
      else
        raise "Unknown additional event: #{event}"
      end
    end
  end
end
