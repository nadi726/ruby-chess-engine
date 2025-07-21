# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'en_passant_event_handler'

# Event handler for MovePieceEvent
class MoveEventHandler
  attr_reader :query, :main, :extras, :from_piece

  def initialize(query, main, extras)
    @query = query
    @from_piece = @query.board.get(main.from)
    @main = normalize_move(main)
    @extras = extras
  end

  def handle
    return invalid_result unless move_valid?
    return handle_move_only unless valid_remove_piece_event?
    return handle_move_pawn if from_piece.type == :pawn

    handle_move_and_remove
  end

  private

  def handle_move_only
    return valid_result([main]) if @query.piece_can_move?(main.from, main.to)

    invalid_result
  end

  def handle_move_and_remove
    return invalid_result unless @query.piece_attacking?(main.from,
                                                         main.to) &&
                                 to_piece && valid_remove_piece_event?

    valid_result([main, remove_piece_event])
  end

  def handle_move_pawn
    en_passant_event_handler = EnPassantEventHandler.new(@query, EnPassantEvent[main.from, main.to], extras)
    en_passant_result = en_passant_event_handler.handle
    return en_passant_result if en_passant_result[:success]

    return invalid_result unless to_piece && @query.piece_attacking?(main.from, main.to)

    valid_result([main, remove_piece_event])
  end

  def normalize_move(event)
    MovePieceEvent[event.from, event.to, from_piece]
  end

  def move_valid?
    event_piece = main&.piece
    (event_piece.nil? || event_piece == from_piece) && from_piece
  end

  def valid_remove_piece_event?
    event = extras.find { _1.is_a?(RemovePieceEvent) }
    return false unless event

    [nil, main.to].include?(event.position) &&
      [nil, to_piece].include?(event.piece)
  end

  def remove_piece_event
    RemovePieceEvent[main.to, to_piece]
  end

  # Always use the to_piece method to access the memoized value.
  # Do not access @to_piece directly to avoid uninitialized or stale values.
  def to_piece
    @to_piece ||= query.board.get(main.to)
  end

  def valid_result(events)
    { success: true, events: events }
  end

  def invalid_result(message = 'Invalid result for MovePieceEvent')
    { success: false, error: message }
  end
end
