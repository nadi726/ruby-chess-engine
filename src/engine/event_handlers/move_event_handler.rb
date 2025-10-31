# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'event_handler'
require_relative 'en_passant_event_handler'

# Event handler for MovePieceEvent
# TODO: Add promotion checks - PromotionEvent if and only if pawn is at one-before-last rank
class MoveEventHandler < EventHandler
  def initialize(query, main, extras)
    super
    @main = normalize_move(main)
  end

  private

  def validate_and_resolve
    return invalid_result unless move_valid?
    return resolve_move_only unless valid_remove_piece_event?
    return resolve_move_pawn if from_piece.type == :pawn

    resolve_move_and_remove
  end

  def resolve_move_only
    return valid_result([main]) if @query.piece_can_move?(main.from, main.to)

    invalid_result
  end

  def resolve_move_and_remove
    return invalid_result unless @query.piece_attacking?(main.from,
                                                         main.to) &&
                                 to_piece && valid_remove_piece_event?

    valid_result([main, remove_piece_event])
  end

  def resolve_move_pawn
    en_passant_event_handler = EnPassantEventHandler.new(@query, EnPassantEvent[main.from, main.to], extras)
    en_passant_result = en_passant_event_handler.process
    return en_passant_result if en_passant_result.success?

    return invalid_result unless to_piece && @query.piece_attacking?(main.from, main.to)

    valid_result([main, remove_piece_event])
  end

  def normalize_move(event)
    MovePieceEvent[event.from, event.to, from_piece]
  end

  def move_valid?
    event_piece = main&.piece
    (event_piece.nil? || event_piece == from_piece) && from_piece && event_piece.color == query.position.current_color
  end

  def valid_remove_piece_event?
    event = extras.find { it.is_a?(RemovePieceEvent) }
    return false unless event

    [nil, main.to].include?(event.square) &&
      [nil, to_piece].include?(event.piece)
  end

  def remove_piece_event
    RemovePieceEvent[main.to, to_piece]
  end

  def invalid_result
    super('Invalid result for MovePieceEvent')
  end
end
