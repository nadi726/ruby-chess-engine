# frozen_string_literal: true

require_relative 'base_parser'
require_relative '../data_definitions/events'
require_relative '../data_definitions/primitives/notation'

# A parser for ERAN, a notation made specifically for the engine.
# See the docs for more details.
class ERANParser < BaseParser
  SQR = /[a-h][1-8]/i
  MOVEMENT = /(?<from>#{SQR})((?<silent>-)|(?<capture>x))(?<to>#{SQR})/i

  PIECE = /pawn|rook|bishop|knight|queen|king|[prbnqk]/i
  PROMOTION = /queen|rook|bishop|knight|[qrbn]/i

  REGULAR_MOVE = /
      (?<piece>#{PIECE})\s+
      (?<movement>#{MOVEMENT})
      (?:\s+(?:->|>)(?<promotion>#{PROMOTION}))?
    /x
  SPECIAL_MOVE = /
    (?:
      (?<en_passant>ep|en-passant)      |
      (?<kingside>ck|castling-kingside) |
      (?<queenside>cq|castling-queenside)
    )/ix

  MOVE = /
    \A\s*
    (?:
      (?<regular>#{REGULAR_MOVE}) |
      (?<special>#{SPECIAL_MOVE})
    )
    \s*\Z
    /ixo

  class << self
    def call(notation, _query = nil)
      match = MOVE.match(notation)
      return unless match

      return parse_special_move(match) if match[:special]

      parse_regular_move(match)
    end

    private

    def parse_special_move(match)
      if match[:en_passant]
        EnPassantEvent[nil, nil, nil]
      elsif match[:kingside]
        CastlingEvent[nil, :kingside]
      elsif match[:queenside]
        CastlingEvent[nil, :queenside]
      end
    end

    def parse_regular_move(match)
      piece = Piece[nil, str_to_piece_type(match[:piece])]
      from = CoreNotation.str_to_square(match[:from].downcase)
      to = CoreNotation.str_to_square(match[:to].downcase)

      event = MovePieceEvent[piece, from, to]
      event = event.capture if match[:capture]
      if (promotion = match[:promotion])
        event = event.promote(str_to_piece_type(promotion))
      end

      event
    end

    def str_to_piece_type(str)
      str = str.downcase
      if Piece::TYPES.include?(str.to_sym)
        str.to_sym
      else
        CoreNotation.str_to_piece(str).type
      end
    end
  end
end
