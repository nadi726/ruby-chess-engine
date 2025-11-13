# frozen_string_literal: true

require_relative '../data_definitions/events'
require_relative 'event_handler'
require_relative 'en_passant_event_handler'

# Event handler for MovePieceEvent
class MoveEventHandler < EventHandler
  private

  def resolve
    return invalid_result("Not a MovePieceEvent: #{event.class}") unless event.is_a?(MovePieceEvent)

    resolving_methods = %i[resolve_to resolve_piece handle_en_passant
                           resolve_from resolve_captured resolve_promote_to]
    en_passant_stop_cond = ->(result) { result.event.is_a?(MovePieceEvent) }
    run_resolution_pipeline(*resolving_methods, handle_en_passant: en_passant_stop_cond)
  end

  # Has to have a full, valid :to
  def resolve_to(event)
    to = event.to
    return invalid_result(":to is not a valid Square: #{to}") unless to.is_a?(Square) && to.valid?

    piece_at_to = board.get(to)
    if piece_at_to&.color == current_color || piece_at_to&.type == :king || (event.captured.nil? && !piece_at_to.nil?)
      return invalid_result("Cannot move to #{to}")
    end

    EventResult.success(event)
  end

  def resolve_piece(event)
    return invalid_result(":piece is not a Piece: #{event.piece}") unless event.piece.is_a?(Piece) || event.piece.nil?
    return invalid_result("Wrong color: #{event.piece.color}") unless [nil, current_color].include?(event.piece&.color)

    piece_color = current_color
    piece_type = event.piece&.type || :pawn # Default to pawn if no piece specified

    # Validate piece type
    unless PIECE_TYPES.include?(piece_type)
      return invalid_result("Invalid piece type: #{piece_type}. Must be one of: #{PIECE_TYPES.join(', ')}")
    end

    piece = Piece[piece_color, piece_type]
    EventResult.success(event.with(piece: piece))
  end

  def resolve_from(event)
    return invalid_result(":from is not a `Square`: #{event.from}") unless event.from.is_a?(Square) || event.from.nil?

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

    return invalid_result('Invalid piece at :from') if filtered_pieces.empty?
    if filtered_pieces.size > 1
      return invalid_result(":from square disambiguation faild: too many pieces: #{filtered_pieces.inspect}")
    end

    _p, from = filtered_pieces.first
    unless event.from.nil? || event.from.matches?(from)
      return invalid_result("Invalid :from square given: #{event.from}. Should be: #{from}")
    end

    EventResult.success(event.with(from: from))
  end

  # Delegate to `EnPassantEventHandler` as needed
  def handle_en_passant(event)
    return EventResult.success(event) unless should_en_passant?(event)

    EnPassantEventHandler.new(@query, EnPassantEvent[event.piece.color, event.from, event.to]).process
  end

  def resolve_captured(event)
    captured = event.captured
    return EventResult.success(event) if captured.nil?

    return invalid_result(":captured is of type #{captured.class}, not CaptureData") unless captured.is_a?(CaptureData)
    unless captured.square.nil? || captured.square.is_a?(Square)
      return invalid_result(":captured.square is not a Square: #{captured.square}")
    end
    unless captured.piece.nil? || captured.piece.is_a?(Piece)
      return invalid_result(":captured.piece is not a Piece: #{captured.piece}")
    end
    return invalid_result('Invalid captured square') unless captured.square.nil? || captured.square.matches?(event.to)

    captured_square = event.to
    captured_piece = board.get(event.to)

    unless [nil, @query.position.other_color].include?(captured.piece&.color) &&
           [nil, captured_piece&.type].include?(captured.piece&.type)
      return invalid_result("Invalid captured piece: #{captured.piece}, should be #{captured_piece}")
    end
    return invalid_result("No piece to capture at #{captured_square}") if captured_piece.nil?

    EventResult.success(event.with(captured: CaptureData[captured_square, captured_piece]))
  end

  def resolve_promote_to(event)
    return EventResult.success(event) if event.piece.type != :pawn && event.promote_to.nil?
    return invalid_result(":promote_to proivded for a non pawn #{event.piece}") unless event.piece.type == :pawn

    unless should_promote?(event)
      result = if event.promote_to.nil?
                 return EventResult.success(event)
               else
                 invalid_result("Cannot promote pawn at #{event.to}")
               end
      return result
    end

    return invalid_result("Pawn move to #{event.to} requires promotion") if event.promote_to.nil?

    promotion_types = %i[queen knight rook bishop]
    unless promotion_types.include?(event.promote_to)
      return invalid_result("Invalid promotion piece type: #{event.promote_to}. Needs to be one of: #{promotion_types}")
    end

    EventResult.success(event)
  end

  def should_en_passant?(event)
    @query.position.en_passant_target && (event.piece.type == :pawn) && !event.captured.nil? &&
      event.to == @query.position.en_passant_target && event.promote_to.nil? &&
      board.get(event.to).nil?
  end

  def should_promote?(*)
    false # TODO
  end
end
