# frozen_string_literal: true

require_relative '../data_definitions/events'

# Event handler for EnPassantEvent
class EnPassantEventHandler
  attr_reader :query, :main, :extras, :from_piece

  def initialize(query, main, extras)
    @query = query
    @from_piece = @query.board.get(main.from)
    @main = main
    @extras = extras
  end

  def handle
    return invalid_result unless valid_en_passant?

    valid_result([main])
  end

  private

  def valid_en_passant?
    query.data.en_passant_target &&
      query.data.en_passant_target == main.to &&
      from_piece&.type == :pawn &&
      main.from.distance(main.to) == [1, 1] &&
      @query.current_pieces.include?(from_piece)
  end

  def valid_result(events)
    { success: true, events: events }
  end

  def invalid_result(message = 'Invalid result for EnPassantEvent')
    { success: false, error: message }
  end
end
