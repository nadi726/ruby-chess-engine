# frozen_string_literal: true

require 'immutable'
require_relative 'game_state'

# Provides derived information about the current game state.
# Centralizes logic for answering queries such as possible movement, attacks, or draw conditions.
class GameQuery
  attr_reader :data, :move_history, :position_signatures, :board

  def initialize(data, move_history = Immutable::List[], position_signatures = Immutable::Hash[])
    @data = data
    @move_history = Immutable.from move_history
    @position_signatures = Immutable.from position_signatures
    @board = data.board # For easier access
  end

  def state
    @state ||= GameState.new(data: data, move_history: move_history, position_signatures: position_signatures)
  end

  # Determines if a piece at the given position is attacking a target position.
  def piece_attacking?(from, target_position)
    piece = board.get(from)
    target_piece = board.get(target_position)
    return false unless piece && target_piece && piece.color != target_piece.color

    piece.threatened_squares(board, from).include?(target_position)
  end

  def piece_can_move?(from, to)
    piece = board.get(from)
    all_pieces.include?(piece) && board.get(to).nil? && piece.moves(board, from).include?(to)
  end

  # returns true if the king of the specified color is in check
  def in_check?(color = @data.current_color)
    _k, king_pos = king_with_pos(color)
    other_pieces_positions = @board.pieces_with_positions(color: color == :white ? :black : :white)
    other_pieces_positions.any? do |_, piece_pos|
      piece_attacking?(piece_pos, king_pos)
    end
  end

  # returns true if the king of the specified color is in checkmate
  def in_checkmate?(color = @data.current_color)
    in_check?(color) && no_legal_moves?(color)
  end

  # returns true if the game is in stalemate
  def in_stalemate?
    !in_check? && no_legal_moves?(@data.current_color)
  end

  def current_pieces
    @board.find_pieces(color: @data.current_color)
  end

  def other_pieces
    @board.find_pieces(color: @data.other_color)
  end

  def all_pieces
    board.find_pieces
  end

  def king_with_pos(color)
    @board.pieces_with_positions(color: color, type: :king).first
  end

  private

  # Returns true if there are no legal moves for the given color
  def no_legal_moves?(color)
    each_pseudo_legal_event_sequence(color).all? do |events|
      state.apply_events(events).query.in_check?(color)
    end
  end

  # A pseudo-legal move is a move that is valid according to the rules of chess,
  # except that it does not account for whether the move would leave the king in check.
  def each_pseudo_legal_event_sequence(color, &)
    return enum_for(__method__, color) unless block_given?

    board.pieces_with_positions(color: color).each do |piece, pos|
      each_move_only_event_sequence(piece, pos, &)
      each_capture_event_sequence(piece, pos, &)
      each_promotion_event_sequence(piece, pos, &)
    end

    each_enpassant_event_sequence(color, &)
    each_castling_event_sequence(color, &)
  end

  def each_move_only_event_sequence(piece, pos)
    piece.moves(board, pos).each do |target_pos|
      next unless piece_can_move?(pos, target_pos) && !move_should_promote?(piece, target_pos)

      yield [MovePieceEvent[pos, target_pos, piece]]
    end
  end

  def each_capture_event_sequence(piece, pos)
    piece.threatened_squares(board, pos).each do |target_pos|
      next unless piece_attacking?(pos, target_pos) && !move_should_promote?(piece, target_pos)

      move_event = MovePieceEvent[pos, target_pos, piece]
      remove_event = RemovePieceEvent[target_pos, board.get(target_pos)]
      yield [move_event, remove_event]
    end
  end

  def each_promotion_event_sequence(piece, pos)
    # Nothing yet
    enum_for(__method__, piece, pos) unless block_given?
  end

  def each_enpassant_event_sequence(color)
    # Nothing yet
    enum_for(__method__, color) unless block_given?
  end

  def each_castling_event_sequence(color)
    enum_for(__method__, color) unless block_given?
    # sides = @data.castling_rights.get_sidet)(color)
    # valid_sides = %i[kingside queenside].select { sides.public_send(it) }
    # valid_sides.map { CastlingEvent[color, it] }
  end

  def move_should_promote?(piece, target_pos)
    piece.type == :pawn &&
      ((piece.color == :white && target_pos.rank == 8) ||
       (piece.color == :black && target_pos.rank == 1))
  end
end
