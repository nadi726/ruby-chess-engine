# frozen_string_literal: true

require_relative 'board'
require_relative 'primitives/colors'
require_relative 'primitives/core_notation'
require_relative 'components/castling_rights'

module ChessEngine
  # Namespace for `Position` and related stuff
  module PositionModule
    # Immutable container for all the data about the current chess position:
    # board layout, active color, en passant target, castling rights, halfmove clock, and fullmove number.
    Position = Data.define(
      :board,
      :current_color,
      :en_passant_target,
      :castling_rights,
      :halfmove_clock,
      :fullmove_number
    ) do
      def self.start
        Position[
          board: Board.start,
          current_color: :white,
          en_passant_target: nil,
          castling_rights: CastlingRights.start,
          halfmove_clock: 0,
          fullmove_number: 1
        ]
      end

      def self.from_fen(str)
        FENConverter.from_fen(str)
      end

      def to_fen
        FENConverter.to_fen(self)
      end

      # An identifier for indicating whether positions are identical in the context of position repetitions,
      # as used for threefold/fivefold repetition detection.
      def signature
        [
          board,
          current_color,
          en_passant_target,
          castling_rights
        ].hash
      end

      def other_color
        Colors.flip(current_color)
      end
    end

    # Converts between `Position` and FEN.
    module FENConverter
      extend self

      def from_fen(str)
        arr = str.split
        raise ArgumentError, 'Not a valid FEN' unless arr.size == 6

        board_str, color_str, castling_rights_str, en_passant_target_str, halfmove_clock_str, fullmove_number_str = arr

        board = fen_to_board(board_str)
        color = case color_str
                when 'w' then :white
                when 'b' then :black
                else raise ArgumentError, "Not a valid color #{color_str}"
                end
        castling_rights = CoreNotation.str_to_castling_rights(castling_rights_str)
        en_passant_target = en_passant_target_str == '-' ? nil : CoreNotation.str_to_square(en_passant_target_str)

        Position[
          board: board,
          current_color: color,
          en_passant_target: en_passant_target,
          castling_rights: castling_rights,
          halfmove_clock: halfmove_clock_str.to_i,
          fullmove_number: fullmove_number_str.to_i
        ]
      end

      def to_fen(pos)
        board_str = board_to_fen(pos.board)
        color_str = pos.current_color == :white ? 'w' : 'b'
        castling_rights_str = CoreNotation.castling_rights_to_str(pos.castling_rights)
        en_passant_target_str = pos.en_passant_target.nil? ? '-' : CoreNotation.square_to_str(pos.en_passant_target)

        "#{board_str} #{color_str} #{castling_rights_str} #{en_passant_target_str} #{pos.halfmove_clock} #{pos.fullmove_number}"
      end

      private

      def fen_to_board(str)
        board_array = str.split('/').reverse.map do |row|
          row.chars.map do |piece|
            if ('1'..'8').include?(piece)
              [nil] * piece.to_i
            else
              CoreNotation.str_to_piece(piece)
            end
          end
        end
        Board.from_flat_array(board_array.flatten)
      end

      def board_to_fen(board)
        ranks = board.each_rank.map do |rank|
          rank_to_fen(rank)
        end
        ranks.reverse.join('/')
      end

      def rank_to_fen(rank)
        rank_str = ''
        nil_count = 0
        rank.each do |piece|
          if piece.nil?
            nil_count += 1
          else
            rank_str += nil_count.to_s unless nil_count.zero?
            rank_str += CoreNotation.piece_to_str(piece)
            nil_count = 0
          end
        end
        rank_str += nil_count.to_s unless nil_count.zero?
        rank_str
      end
    end
  end

  CastlingSides = PositionModule::CastlingSides
  CastlingRights = PositionModule::CastlingRights
  Position = PositionModule::Position
end
