# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative '../data_definitions/castling_data'
require_relative 'event_handler'

class CastlingEventHandler < EventHandler
  private

  def resolve
    return failure("#{event} is not a CastlingEvent") unless event.is_a?(CastlingEvent)

    run_resolution_pipeline(:resolve_color, :resolve_side)
  end

  def resolve_color(event)
    return failure("Not a color: #{event.color}") unless [nil, *COLORS].include?(event.color)
    return failure("Unexpected color: #{event.color} (expected #{current_color})") if event.color == other_color

    success(event.with(color: current_color))
  end

  def resolve_side(event)
    return failure("Not a valid side: #{event.side}") unless CASTLING_SIDES.include?(event.side)

    sides = position.castling_rights.sides(event.color)
    return failure("No rights for side #{event.side}") unless sides.side?(event.side)

    king_is_attacked = CastlingData.king_path(event.color, event.side).any? do |sq|
      query.square_attacked?(sq, other_color)
    end
    return failure('King is under attack somewhere on the path') if king_is_attacked

    path_is_clear = CastlingData.intermediate_squares(event.color, event.side).all? do |sq|
      board.get(sq).nil?
    end

    return failure('Path between king and rook is obstructed') unless path_is_clear

    success(event)
  end
end
