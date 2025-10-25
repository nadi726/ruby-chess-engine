# frozen_string_literal: true

require_relative '../errors'

# An internal module for GameQuery
# Check that there are no legal moves for the given color
module NoLegalMovesHelper
  private

  # Entry point
  def no_legal_moves?(color)
    each_pseudo_legal_event_sequence(color).all? do |events|
      state.apply_events(events).query.in_check?(color)
    rescue InvalidEventSequenceError
      true # Malformed event sequences are considered illegal moves
    end
  end

  # A pseudo-legal move is a move that is valid according to the rules of chess,
  # except that it does not account for whether the move would leave the king in check.
  def each_pseudo_legal_event_sequence(color, &)
    return enum_for(__method__, color) unless block_given?

    board.pieces_with_positions(color: color).each do |piece, pos|
      each_move_only_event_sequence(piece, pos, &)
      each_capture_event_sequence(piece, pos, &)
    end

    each_enpassant_event_sequence(color, &)
    each_castling_event_sequence(color, &)
  end

  def each_move_only_event_sequence(piece, pos, &)
    moves = piece.moves(board, pos).select { board.get(it).nil? }

    each_move_event_sequence(piece, pos, moves, &)
  end

  def each_capture_event_sequence(piece, pos, &) # rubocop:disable Metrics/AbcSize
    capture_moves = piece.threatened_squares(board, pos).select do |target_pos|
      target_piece = board.get(target_pos)
      !target_piece.nil? && piece.color != target_piece.color
    end

    each_move_event_sequence(piece, pos, capture_moves) do |events|
      target_piece = events.first.to
      yield events + [RemovePieceEvent[target_piece, board.get(target_piece)]]
    end
  end

  def each_move_event_sequence(piece, pos, moves, &)
    moves.each do |target_pos|
      events = [MovePieceEvent[pos, target_pos, piece]]

      if move_should_promote?(piece, target_pos)
        each_promotion_event_sequence(events, &)
      else
        yield events
      end
    end
  end

  def each_promotion_event_sequence(events, &)
    %i[queen rook bishop knight].each do |piece_type|
      yield events + [PromotePieceEvent[piece_type]]
    end
  end

  def each_enpassant_event_sequence(color, &)
    return unless can_en_passant?(color)

    rank_offset = color == :white ? -1 : 1
    [1, -1].each do |file_offset|
      pos = data.en_passant_target.offset(file_offset, rank_offset)
      next unless pos.valid? && board.get(pos) == Piece[color, :pawn]

      yield [EnPassantEvent[pos, data.en_passant_target]]
    end
  end

  def each_castling_event_sequence(color) # rubocop:disable Metrics/AbcSize
    sides = @data.castling_rights.get_side(color)
    valid_sides = %i[kingside queenside].select { sides.public_send(it) }
    events = valid_sides.map { CastlingEvent[color, it] }
                        # Filter occupied positions
                        .select { board.get(it.king_to).nil? && board.get(it.rook_to).nil? }
    events.each { yield [it] }
  end

  def move_should_promote?(piece, target_pos)
    piece.type == :pawn &&
      ((piece.color == :white && target_pos.rank == 8) ||
       (piece.color == :black && target_pos.rank == 1))
  end

  def can_en_passant?(color)
    data.en_passant_target && (
    (color == :white && data.en_passant_target.rank == 6) ||
    (color == :black && data.en_passant_target.rank == 3)
  )
  end
end
