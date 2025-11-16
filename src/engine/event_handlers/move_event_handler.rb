# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'event_handler'
require_relative 'en_passant_event_handler'

# Event handler for MovePieceEvent
class MoveEventHandler < EventHandler
  private

  def resolve
    return failure("#{event} is not a MovePieceEvent") unless event.is_a?(MovePieceEvent)

    resolving_methods = %i[resolve_to resolve_piece handle_en_passant
                           resolve_from resolve_captured resolve_promote_to]
    en_passant_stop_cond = ->(result) { result.event.is_a?(MovePieceEvent) }
    run_resolution_pipeline(*resolving_methods, handle_en_passant: en_passant_stop_cond)
  end

  # Has to have a full, valid :to
  def resolve_to(event)
    to = event.to
    return failure(":to is not a valid Square: #{to}") unless to.is_a?(Square) && to.valid?

    piece_at_to = board.get(to)
    if piece_at_to&.color == current_color || piece_at_to&.type == :king || (event.captured.nil? && !piece_at_to.nil?)
      return failure("Cannot move to #{to}")
    end

    success(event)
  end

  def resolve_piece(event)
    return failure(":piece is not a Piece: #{event.piece}") unless event.piece.is_a?(Piece) || event.piece.nil?
    return failure("Wrong color: #{event.piece.color}") unless [nil, current_color].include?(event.piece&.color)

    piece_color = current_color
    piece_type = event.piece&.type || :pawn # Default to pawn if no piece specified

    # Validate piece type
    unless PIECE_TYPES.include?(piece_type)
      return failure("Invalid piece type: #{piece_type}. Must be one of: #{PIECE_TYPES.join(', ')}")
    end

    piece = Piece[piece_color, piece_type]
    success(event.with(piece: piece))
  end

  def resolve_from(event)
    return failure(":from is not a `Square`: #{event.from}") unless event.from.is_a?(Square) || event.from.nil?

    # Determine the appropriate method to get piece moves,
    # either `Piece#moves` or `Piece#threatened_squares`
    piece_moves_method = board.get(event.to).nil? ? :moves : :threatened_squares
    filtered_pieces = board.pieces_with_squares(color: event.piece.color, type: event.piece.type).select do |_p, s|
      event.from.nil? || event.from.matches?(s)
    end

    # Filter pieces that can move to the destination
    filtered_pieces = filtered_pieces.select do |p, s|
      piece_moves = p.send(piece_moves_method, board, s)
      piece_moves.any? { event.to == it }
    end

    return failure('Invalid piece at :from') if filtered_pieces.empty?
    if filtered_pieces.size > 1
      return failure(":from square disambiguation faild: too many pieces: #{filtered_pieces.inspect}")
    end

    _p, from = filtered_pieces.first
    unless event.from.nil? || event.from.matches?(from)
      return failure("Invalid :from square given: #{event.from}. Should be: #{from}")
    end

    success(event.with(from: from))
  end

  # Delegate to `EnPassantEventHandler` as needed
  def handle_en_passant(event)
    return success(event) unless should_en_passant?(event)

    EnPassantEventHandler.call(@query, EnPassantEvent[event.piece.color, event.from, event.to])
  end

  def resolve_captured(event)
    captured = event.captured
    return success(event) if captured.nil?

    return failure(":captured is of type #{captured.class}, not CaptureData") unless captured.is_a?(CaptureData)
    unless captured.square.nil? || captured.square.is_a?(Square)
      return failure(":captured.square is not a Square: #{captured.square}")
    end
    unless captured.piece.nil? || captured.piece.is_a?(Piece)
      return failure(":captured.piece is not a Piece: #{captured.piece}")
    end
    return failure('Invalid captured square') unless captured.square.nil? || captured.square.matches?(event.to)

    captured_square = event.to
    captured_piece = board.get(event.to)

    unless [nil, other_color].include?(captured.piece&.color) &&
           [nil, captured_piece&.type].include?(captured.piece&.type)
      return failure("Invalid captured piece: #{captured.piece}, should be #{captured_piece}")
    end
    return failure("No piece to capture at #{captured_square}") if captured_piece.nil?

    success(event.with(captured: CaptureData[captured_square, captured_piece]))
  end

  PROMOTION_TYPES = %i[queen knight rook bishop].freeze
  private_constant :PROMOTION_TYPES
  def resolve_promote_to(event)
    promote_to = event.promote_to
    unless should_promote?(event)
      return success(event) if promote_to.nil?

      return failure("Given promotion, but cannot promote #{event.piece.type} at #{event.to}")
    end

    return failure("Pawn move to #{event.to} requires promotion") if promote_to.nil?

    unless PROMOTION_TYPES.include?(promote_to)
      return failure("Invalid promotion piece type: #{promote_to}. Needs to be one of: #{PROMOTION_TYPES.join(', ')}")
    end

    success(event)
  end

  def should_en_passant?(event)
    position.en_passant_target && (event.piece.type == :pawn) && !event.captured.nil? &&
      event.to == position.en_passant_target && event.promote_to.nil? &&
      board.get(event.to).nil?
  end

  def should_promote?(event)
    event.piece.type == :pawn &&
      ((current_color == :white && event.to.rank == 8) || (current_color == :black && event.to.rank == 1))
  end
end
