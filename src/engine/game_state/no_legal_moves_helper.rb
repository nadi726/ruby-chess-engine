# frozen_string_literal: true

require_relative '../errors'
require_relative '../data_definitions/events'
require_relative '../data_definitions/piece'
require_relative '../data_definitions/castling_data'

# An internal module for `GameQuery`
# Check that there are no legal moves for the given color
module NoLegalMovesHelper
  private

  # Entry point
  def no_legal_moves?(color)
    each_pseudo_legal_event(color).all? do |event|
      state.apply_event(event).query.in_check?(color)
    rescue InvalidEventError
      true # Malformed events are considered illegal moves
    end
  end

  # A pseudo-legal move is a move that is valid according to the rules of chess,
  # except that it does not account for whether the move would leave the king in check.
  def each_pseudo_legal_event(color, &)
    return enum_for(__method__, color) unless block_given?

    board.pieces_with_squares(color: color).each do |piece, square|
      each_move_only_event(piece, square, &)
      each_capture_event(piece, square, &)
    end

    each_enpassant_event(color, &)
    each_castling_event(color, &)
  end

  def each_move_only_event(piece, square, &)
    to_squares = piece.moves(board, square).select { board.get(it).nil? }

    each_move_event(piece, square, to_squares, &)
  end

  def each_capture_event(piece, square, &)
    capturable_squares = piece.threatened_squares(board, square).select do |target_square|
      target_piece = board.get(target_square)
      !target_piece.nil? && piece.color != target_piece.color
    end

    each_move_event(piece, square, capturable_squares) do |event|
      yield event.capture(event.to, board.get(event.to))
    end
  end

  def each_move_event(piece, square, to_squares, &)
    to_squares.each do |target_square|
      event = MovePieceEvent[piece, square, target_square]

      if move_should_promote?(piece, target_square)
        each_promotion_event(event, &)
      else
        yield event
      end
    end
  end

  def each_promotion_event(event, &)
    %i[queen rook bishop knight].each do |piece_type|
      yield event.promote(piece_type)
    end
  end

  def each_enpassant_event(color, &)
    return unless can_en_passant?(color)

    rank_offset = color == :white ? -1 : 1
    [1, -1].each do |file_offset|
      square = position.en_passant_target.offset(file_offset, rank_offset)
      next unless square.valid? && board.get(square) == Piece[color, :pawn]

      yield EnPassantEvent[color, square, position.en_passant_target]
    end
  end

  def each_castling_event(color)
    CASTLING_SIDES.each do |side|
      next unless castling_available?(color, side)

      yield CastlingEvent[color, side]
    end
  end

  def move_should_promote?(piece, target_pos)
    piece.type == :pawn &&
      ((piece.color == :white && target_pos.rank == 8) ||
      (piece.color == :black && target_pos.rank == 1))
  end

  def can_en_passant?(color)
    position.en_passant_target && (
      (color == :white && position.en_passant_target.rank == 6) ||
      (color == :black && position.en_passant_target.rank == 3)
    )
  end

  def castling_available?(color, side)
    has_rights = @position.castling_rights.sides(color).public_send(side)
    return false unless has_rights

    king_is_attacked = CastlingData.king_path(color, side).any? do |sq|
      square_attacked?(sq, position.other_color)
    end
    path_is_clear = CastlingData.intermediate_squares(color, side).all? do |sq|
      board.get(sq).nil?
    end

    !king_is_attacked && path_is_clear
  end
end
