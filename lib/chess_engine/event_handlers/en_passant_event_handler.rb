# frozen_string_literal: true

require_relative 'base_event_handler'
require_relative '../data_definitions/events'
require_relative '../data_definitions/square'
require_relative '../data_definitions/primitives/colors'

module ChessEngine
  module EventHandlers
    # Event handler for `EnPassantEvent`
    class EnPassantEventHandler < BaseEventHandler
      private

      def resolve
        return failure("#{event} is not an EnPassantEvent") unless event.is_a?(EnPassantEvent)
        return failure('EnPassant not available') unless en_passant_target

        run_resolution_pipeline(:resolve_color, :resolve_to, :resolve_from)
      end

      def resolve_color(event)
        return failure("Not a color: #{event.color}") unless event.color.nil? || Colors.valid?(event.color)
        return failure("Unexpected color: #{event.color} (expected #{current_color})") if event.color == other_color

        success(event.with(color: current_color))
      end

      def resolve_to(event)
        return failure(":to is not a Square: #{event.to}") unless event.to.is_a?(Square)
        return failure("Cannot en passant to #{event.to}") unless event.to.matches?(en_passant_target)

        success(event.with(to: en_passant_target))
      end

      def resolve_from(event)
        return failure(":from is not a Square: #{event.from}") unless event.from.nil? || event.from.is_a?(Square)

        filtered_squares = determine_from(event)
        return failure("#{event.from} is not a valid :from square for this move") if filtered_squares.empty?
        if filtered_squares.size > 1
          return failure("Disambiguation failed. :from (#{event.from}) could be either one of: #{filtered_squares.inspect}")
        end

        success(event.with(from: filtered_squares.first))
      end

      def determine_from(event)
        rank_offset = event.color == :white ? -1 : 1
        offsets = [[1, rank_offset], [-1, rank_offset]]
        offsets.filter_map do |file_off, rank_off|
          sq = en_passant_target.offset(file_off, rank_off)
          sq if sq.valid? && board.get(sq) == event.piece && (event.from.nil? || event.from.matches?(sq))
        end
      end

      def en_passant_target = position.en_passant_target
    end
  end
end
