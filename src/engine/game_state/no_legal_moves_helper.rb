# frozen_string_literal: true

require_relative '../errors'

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
    moves = piece.moves(board, square).select { board.get(it).nil? }

    each_move_event(piece, square, moves, &)
  end

  def each_capture_event(piece, square, &)
    capture_moves = piece.threatened_squares(board, square).select do |target_pos|
      target_piece = board.get(target_pos)
      !target_piece.nil? && piece.color != target_piece.color
    end

    each_move_event(piece, square, capture_moves) do |event|
      target_piece = event.to
      yield event.capture(target_piece, board.get(target_piece))
    end
  end

  def each_move_event(piece, square, moves, &)
    moves.each do |target_pos|
      event = MovePieceEvent[piece, square, target_pos]

      if move_should_promote?(piece, target_pos)
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

  def each_castling_event(color) # rubocop:disable Metrics/AbcSize
    # TODO: - enforce full castling restrictions: can't castle when there are pieces between,
    #         or when either of the squares the king moves through are attacked
    sides = @position.castling_rights.get_side(color)
    valid_sides = %i[kingside queenside].select { sides.public_send(it) }
    event = valid_sides.map { CastlingEvent[it, color] }
                       # Filter occupied squares
                       .select { board.get(it.king_to).nil? && board.get(it.rook_to).nil? }
    event.each { yield it }
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
end
