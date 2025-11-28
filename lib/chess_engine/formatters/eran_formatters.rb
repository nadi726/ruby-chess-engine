# frozen_string_literal: true

require 'immutable'
require_relative 'validation'
require_relative '../data_definitions/primitives/core_notation'

module ChessEngine
  module Formatters
    # Provides formatters for ERAN, a custom chess notation made for this engine.
    #
    # ERAN supports both long and short forms for many constructs; this module exposes formatters for each style.
    # See the docs for ERAN for more details.
    module ERANFormatters
      extend self

      PROMOTION_PREFIX = { long: '->', short: '>' }.freeze
      EN_PASSANT = { long: 'en-passant', short: 'ep' }.freeze
      CASTLING = Immutable.from(
        {
          long: {
            kingside: 'castling-kingside',
            queenside: 'castling-queenside'
          },
          short: {
            kingside: 'ck',
            queenside: 'cq'
          }
        }
      )

      # Since ERAN is case-insensitive, capitalizing piece type is only for aesthetic.
      PIECE_TYPES = Immutable.from(
        { long: Piece::TYPES.to_h { [it, it.to_s.capitalize] },
          short: CoreNotation::PIECE_MAP }
      )

      def format(event, verbosity)
        case event
        in MovePieceEvent
          format_move_piece_event(event, PIECE_TYPES[verbosity], PROMOTION_PREFIX[verbosity])
        in EnPassantEvent
          EN_PASSANT[verbosity]
        in CastlingEvent
          CASTLING[verbosity][event.side]
        else
          nil
        end
      end

      def format_move_piece_event(event, piece_types, promotion_prefix) # rubocop:disable Metrics/AbcSize
        return unless Validation.well_formed_move_piece?(event)

        piece_type = piece_types[event.piece.type]
        move_type = event.captured.nil? ? '-' : 'x'
        movement = CoreNotation.square_to_str(event.from) + move_type + CoreNotation.square_to_str(event.to)
        promotion = event.promote_to ? promotion_prefix + piece_types[event.promote_to] : nil

        [piece_type, movement, promotion].compact.join(' ')
      end

      private :format, :format_move_piece_event

      # The actual formatters
      LONG = ->(event) { format(event, :long) }
      SHORT = ->(event) { format(event, :short) }
    end

    ERANLongFormatter = ERANFormatters::LONG
    ERANShortFormatter = ERANFormatters::SHORT
  end
end
