# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'event_handler'

# Event handler for EnPassantEvent
class EnPassantEventHandler < EventHandler
  private

  def validate_and_resolve
    return invalid_result unless valid_en_passant?

    valid_result([main])
  end

  def valid_en_passant?
    query.position.en_passant_target &&
      query.position.en_passant_target == main.to &&
      from_piece&.type == :pawn &&
      main.from.distance(main.to) == [1, 1] &&
      @query.current_pieces.include?(from_piece)
  end

  def invalid_result
    super('Invalid result for EnPassantEvent')
  end
end
