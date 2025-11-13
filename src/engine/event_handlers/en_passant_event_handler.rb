# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative '../data_definitions/colors'
require_relative 'event_handler'

# Event handler for `EnPassantEvent`
class EnPassantEventHandler < EventHandler
  private

  def resolve
    return invalid_result("#{event} is not an EnPassantEvent") unless event.is_a?(EnPassantEvent)
    return invalid_result('EnPassant not available') unless en_passant_target

    run_resolution_pipeline(:resolve_color, :resolve_to, :resolve_from)
  end

  def resolve_color(event)
    return invalid_result(":to is not a color: #{event.color}") unless [nil, *COLORS].include?(event.color)
    return invalid_result("Wrong color: #{event.piece.color}") unless [nil, current_color].include?(event.color)

    EventResult.success(event.with(color: current_color))
  end

  def resolve_to(event)
    return invalid_result(":to is not a Square: #{event.to}") unless event.to.is_a?(Square)
    return invalid_result("Cannot en passsant to #{event.to}") unless event.to.matches?(en_passant_target)

    EventResult.success(event.with(to: en_passant_target))
  end

  def resolve_from(event)
    return invalid_result(":from is not a Square: #{event.from}") unless event.from.nil? || event.from.is_a?(Square)

    filtered_squares = determine_from(event)
    return invalid_result("#{event.from} is not a valid :from square for this move") if filtered_squares.empty?
    if filtered_squares.size > 1
      return invalid_result("Disambiguation failed. :from (#{event.from}) could be either one of: #{filtered_squares.inspect}")
    end

    EventResult.success(event.with(from: filtered_squares.first))
  end

  def determine_from(event)
    rank_offset = event.color == :white ? -1 : 1
    offsets = [[1, rank_offset], [-1, rank_offset]]
    offsets.filter_map do |file_off, rank_off|
      sq = en_passant_target.offset(file_off, rank_off)
      sq if sq.valid? && board.get(sq) == event.piece && (event.from.nil? || event.from.matches?(sq))
    end
  end

  def en_passant_target = @query.position.en_passant_target
end
