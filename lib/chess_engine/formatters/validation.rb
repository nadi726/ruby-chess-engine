# frozen_string_literal: true

require_relative '../data_definitions/piece'
require_relative '../data_definitions/square'
require_relative '../data_definitions/primitives/colors'
require_relative '../data_definitions/primitives/castling_data'

module ChessEngine
  module Formatters
    # Utilities for checking the structural validity of the given event
    module Validation
      module_function

      # --- Shallow validity: basic fields required for most notation ---
      # Only checks presence and immediate validity of fields, not nested captured pieces, color, etc.
      def well_formed_move_piece?(event)
        Piece::TYPES.include?(event.piece&.type) &&
          square_and_valid?(event.from) &&
          square_and_valid?(event.to) &&
          (event.promote_to.nil? || Piece::PROMOTION_TYPES.include?(event.promote_to))
      end

      def well_formed_en_passant?(_event)
        true # Most notations don't need any special validation for en passant
      end

      def well_formed_castling?(event)
        CastlingData::SIDES.include?(event.side)
      end

      # --- Full validity: all nested fields and optional data are checked ---
      # Useful when you want to ensure the event is completely well-formed for any purpose.
      def fully_well_formed_move_piece?(event)
        well_formed_move_piece?(event) && Colors.valid?(event.piece.color) &&
          (event.captured.nil? || (square_and_valid?(event.captured.square) && piece_and_valid?(event.captured.piece)))
      end

      def fully_well_formed_en_passant?(event)
        Colors.valid?(event.color) &&
          (event.from.nil? || square_and_valid?(event.from)) &&
          (event.to.nil? || square_and_valid?(event.to))
      end

      def fully_well_formed_castling?(event)
        well_formed_castling?(event) && Colors.valid?(event.color)
      end

      # --- Components helpers ---
      # Validate basic pieces or squares
      def piece_and_valid?(piece) = piece.is_a?(Piece) && piece.valid?
      def square_and_valid?(square) = square.is_a?(Square) && square.valid?
    end
  end
end
