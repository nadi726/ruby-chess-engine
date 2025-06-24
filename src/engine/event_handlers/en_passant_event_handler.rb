# frozen_string_literal: true

require_relative '../data_definitions/events'

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
