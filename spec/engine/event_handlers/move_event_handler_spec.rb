# frozen_string_literal: true

require 'game_state/game_query'
require 'game_state/board'
require 'game_state/position'
require 'event_handlers/move_event_handler'
require 'data_definitions/events'
require 'data_definitions/square'

RSpec.describe MoveEventHandler do
  # A board & query setup used for most of the tests
  let(:board) do
    fill_board(
      # White pieces
      [
        [Piece[:white, :king], Square[:e, 1]],
        [Piece[:white, :rook], Square[:a, 1]],
        [Piece[:white, :rook], Square[:a, 7]],
        [Piece[:white, :pawn], Square[:d, 5]],
        [Piece[:white, :knight], Square[:b, 1]],
        # Black pieces
        [Piece[:black, :king], Square[:e, 8]],
        [Piece[:black, :queen], Square[:d, 8]],
        [Piece[:black, :pawn], Square[:c, 6]],
        [Piece[:black, :pawn], Square[:h, 2]],
        [Piece[:black, :bishop], Square[:h, 8]]
      ]
    )
  end

  let(:white_query) do
    GameQuery.new(Position.start.with(board: board))
  end

  let(:black_query) do
    GameQuery.new(white_query.position.with(current_color: :black))
  end

  context 'simple moves' do
    it 'returns valid result for 1-rank pawn move' do
      event = MovePieceEvent[nil, Square[:d, 2], Square[:d, 3]]
      result = MoveEventHandler.call(start_query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'returns valid result for 2-rank pawn move' do
      event = MovePieceEvent[nil, Square[:f, 2], Square[:f, 4]]
      result = MoveEventHandler.call(start_query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'returns invalid result for 3-rank pawn move' do
      event = MovePieceEvent[nil, Square[:g, 2], Square[:f, 5]]
      result = MoveEventHandler.call(start_query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'returns valid result for valid knight move' do
      event = MovePieceEvent[Piece[:white, :knight], Square[:b, 1], Square[:c, 3]]
      result = MoveEventHandler.call(start_query, event)
      expect(result).to be_a_successful_handler_result
    end
  end

  context 'for complex state' do
    it 'allows white rook to move to a5' do
      event = MovePieceEvent[Piece[:white, :rook], Square[:a, 1], Square[:a, 5]]
      result = MoveEventHandler.call(white_query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'prevents white pawn from moving to c6 (blocked by black pawn)' do
      event = MovePieceEvent[nil, Square[:d, 5], Square[:c, 6]]
      result = MoveEventHandler.call(white_query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'allows white knight to jump to c3' do
      event = MovePieceEvent[Piece[nil, :knight], Square[:b, 1], Square[:c, 3]]
      result = MoveEventHandler.call(white_query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'prevents white rook from moving through white knight' do
      event = MovePieceEvent[Piece[nil, :rook], Square[:a, 1], Square[:c, 1]]
      result = MoveEventHandler.call(white_query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'allows black queen to capture white pawn on d5 with empty #capture' do
      event = MovePieceEvent[Piece[nil, :queen], Square[:d, 8], Square[:d, 5]].capture
      result = MoveEventHandler.call(black_query, event)
      expect(result).to be_a_successful_handler_result
    end
    it 'allows black queen to capture white pawn on d5 with full #capture' do
      move = MovePieceEvent[Piece[:black, :queen], Square[:d, 8], Square[:d, 5]]
             .capture(Square[:d, 5], Piece[:white, :pawn])
      result = MoveEventHandler.call(black_query, move)
      expect(result).to be_a_successful_handler_result
    end

    it 'fails when capturing but no capture is given' do
      event = MovePieceEvent[Piece[nil, :queen], Square[:d, 8], Square[:d, 5]]
      result = MoveEventHandler.call(black_query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'prevents black bishop from moving to a1 (blocked by white rook)' do
      event = MovePieceEvent[Piece[:black, :bishop], Square[:h, 8], Square[:a, 1]]
      result = MoveEventHandler.call(black_query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'fails when capture square does not match the target square' do
      move = MovePieceEvent[Piece[:black, :queen], Square[:d, 8], Square[:d, 5]]
             .capture(Square[:c, 6], Piece[:white, :pawn])
      result = MoveEventHandler.call(black_query, move)
      expect(result).to be_a_failed_handler_result
    end

    it 'fails when captured piece is not actually at given square' do
      move = MovePieceEvent[Piece[:black, :queen], Square[:d, 8], Square[:d, 5]]
             .capture(Square[:d, 5], Piece[:white, :knight])
      result = MoveEventHandler.call(black_query, move)
      expect(result).to be_a_failed_handler_result
    end

    it 'fails when moving from an empty square' do
      event = MovePieceEvent[nil, Square[:c, 4], Square[:d, 5]]
      result = MoveEventHandler.call(white_query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'fails when trying to move onto allied piece even with capture' do
      move = MovePieceEvent[Piece[:white, :rook], Square[:a, 1], Square[:b, 1]]
             .capture(Square[:b, 1], Piece[:white, :knight])
      result = MoveEventHandler.call(white_query, move)
      expect(result).to be_a_failed_handler_result
    end

    it 'fails if captured is given but no piece is being captured' do
      move = MovePieceEvent[Piece[:white, :rook], Square[:a, 1], Square[:a, 4]]
             .capture(Square[:a, 4], nil)
      result = MoveEventHandler.call(white_query, move)
      expect(result).to be_a_failed_handler_result
    end

    context 'turn enforcement' do
      it 'prevents black from moving when it is white’s turn' do
        event = MovePieceEvent[nil, Square[:c, 6], Square[:c, 5]]
        result = MoveEventHandler.call(white_query, event)
        expect(result).to be_a_failed_handler_result
      end

      it 'allows black to move on black’s turn' do
        event = MovePieceEvent[Piece[:black, :king], Square[:e, 8], Square[:f, 8]]
        result = MoveEventHandler.call(black_query, event)
        expect(result).to be_a_successful_handler_result
      end
    end
  end

  context 'en passant' do
    let(:black_pawn_move) do
      MovePieceEvent[Piece[:black, :pawn], Square[:d, 7], Square[:d, 5]]
    end

    let(:new_board) do
      fill_board(
        [
          [Piece[:white, :pawn], Square[:e, 5]],
          [Piece[:black, :pawn], Square[:d, 5]]
        ],
        board: board.remove(Square[:d, 5])
      )
    end

    let(:new_move_history) do
      white_query.move_history.add(Immutable::List[black_pawn_move])
    end

    let(:query) do
      GameQuery.new(
        Position.start.with(board: new_board, en_passant_target: Square[:d, 6]),
        new_move_history
      )
    end

    it 'rejects en passant without required events' do
      move_event = MovePieceEvent[nil, Square[:e, 5], Square[:d, 6]]
      result = MoveEventHandler.call(query, move_event)
      expect(result).to be_a_failed_handler_result
    end

    it 'accepts en passant with required events from move event' do
      move_event = MovePieceEvent[nil, Square[:e, 5], Square[:d, 6]].capture
      result = MoveEventHandler.call(query, move_event)
      expect(result).to be_a_successful_handler_result
      expect(result.event).to eq(EnPassantEvent[:white, Square[:e, 5], Square[:d, 6]])
    end
  end

  context 'check detection' do
    it 'continues silently when the king is currently in check but moves out of it' do
      board = fill_board(
        [
          [Piece[:black, :queen], Square[:e, 8]],
          [Piece[:black, :king], Square[:d, 8]],
          [Piece[:white, :king], Square[:e, 1]]
        ]
      )
      query = GameQuery.new(Position.start.with(board: board))
      move_event = MovePieceEvent[Piece[:white, :king], Square[:e, 1], Square[:f, 1]]
      result = MoveEventHandler.call(query, move_event)
      expect(result).to be_a_successful_handler_result
    end

    it 'fails when moving into check' do
      board = fill_board(
        [
          [Piece[:black, :queen], Square[:e, 8]],
          [Piece[:black, :king], Square[:d, 8]],
          [Piece[:white, :rook], Square[:e, 4]],
          [Piece[:white, :king], Square[:e, 1]]
        ]
      )
      query = GameQuery.new(Position.start.with(board: board))
      move_event = MovePieceEvent[Piece[:white, :rook], Square[:e, 4], Square[:b, 4]]
      result = MoveEventHandler.call(query, move_event)
      expect(result).to be_a_failed_handler_result
    end

    it "fails when the king is currently in check and doesn't moves out of it" do
      board = fill_board(
        [
          [Piece[:black, :queen], Square[:e, 8]],
          [Piece[:black, :king], Square[:d, 8]],
          [Piece[:white, :king], Square[:e, 1]]
        ]
      )
      query = GameQuery.new(Position.start.with(board: board))
      move_event = MovePieceEvent[Piece[:white, :king], Square[:e, 1], Square[:e, 2]]
      result = MoveEventHandler.call(query, move_event)

      expect(result).to be_a_failed_handler_result
    end
  end

  describe 'malformed events' do
    let(:base_event) { MovePieceEvent[Piece[:white, :pawn], Square[:d, 2], Square[:d, 4]] }

    def expect_field_values_to_fail(field, vals, fail: true, query: start_query, event: base_event)
      raise "Invalid field: #{field}" unless MovePieceEvent.members.include?(field)

      matcher = fail ? be_a_failed_handler_result : be_a_successful_handler_result
      vals.each do |val|
        event = event.with(field => val)
        result = MoveEventHandler.call(query, event)
        expect(result).to matcher
      end
    end

    it 'rejects when not given a `MovePieceEvent`' do
      expect(MoveEventHandler.call(start_query, EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]])
                            ).to be_a_failed_handler_result
      expect(MoveEventHandler.call(start_query, nil)).to be_a_failed_handler_result
    end

    it 'rejects when `to` is not a valid square' do
      tos = [nil, Square[nil, nil], Square[nil, 4], Square[:x, 10], Square[:e, nil]]
      expect_field_values_to_fail(:to, tos)
    end

    it 'rejects when piece is not an at least partially valid `Piece` or nil' do
      pieces = [:pawn, Piece[:orange, :soldier], Piece[:white, 4], Piece[:pink, :pawn], Piece[:black, :pawn]]
      expect_field_values_to_fail(:piece, pieces)
    end

    it 'rejects when `from` is not at least partially valid' do
      froms = [:somewhere, Square[:great, :place], Square[:d, 100], Square[2, :d], Square[:d, 3]]
      expect_field_values_to_fail(:from, froms)
    end

    it 'rejects when `from` is ambiguous' do
      # Could be either white rook at a1 or white rook at a7
      base_event = MovePieceEvent[Piece[:white, nil], nil, Square[:a, 3]]
      froms = [nil, Square[nil, nil], Square[:a, nil]]
      expect_field_values_to_fail(:from, froms, event: base_event, query: white_query)
    end

    it 'rejects when capture is at least partially given but invalid' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:d, 5], Square[:c, 6]]
      captures = [
        :aha!, CaptureData[Square[:e, :x], nil], CaptureData[Square[:d, 6], nil],
        CaptureData[nil, Piece[:white, :car]], CaptureData[nil, Piece[:white, :pawn]],
        CaptureData[nil, Piece[:black, :king]], CaptureData['stuff', nil], CaptureData[nil, 'stuff']
      ]
      expect_field_values_to_fail(:captured, captures, query: white_query, event: event)
    end

    context 'promotion' do
      it 'rejects when `promote_to` is given for a `to` square that is not eligible' do
        event = MovePieceEvent[Piece[:white, :pawn], Square[:d, 5], Square[:d, 6]].promote(:queen)
        expect(MoveEventHandler.call(white_query, event)).to be_a_failed_handler_result
      end

      it 'rejects when promotion is given to a non-pawn piece' do
        event = MovePieceEvent[Piece[:white, :rook], Square[:a, 1], Square[:a, 8]].promote(:queen)
        expect(MoveEventHandler.call(white_query, event)).to be_a_failed_handler_result
      end

      it 'rejects when promotion is to an invalid piece type' do
        base_event = MovePieceEvent[Piece[:black, :pawn], Square[:h, 2], Square[:h, 1]]
        expect(MoveEventHandler.call(black_query, base_event.promote(:goat))).to be_a_failed_handler_result
        expect(MoveEventHandler.call(black_query, base_event.promote(:king))).to be_a_failed_handler_result
      end

      it 'rejects when promotion should have been given' do
        base_event = MovePieceEvent[Piece[:black, :pawn], Square[:h, 2], Square[:h, 1]]
        expect(MoveEventHandler.call(black_query, base_event)).to be_a_failed_handler_result
      end
    end
  end

  describe 'incomplete but valid events' do
    let(:base_event) { MovePieceEvent[Piece[:white, :pawn], Square[:g, 2], Square[:g, 4]] }

    it 'resolves to pawn when piece not given' do
      result = MoveEventHandler.call(start_query, base_event.with(piece: nil))
      expect(result.event&.piece).to eq(Piece[:white, :pawn])
    end

    it 'resolves piece color when type is given' do
      event = MovePieceEvent[Piece[nil, :knight], nil, Square[:a, 3]]
      result = MoveEventHandler.call(start_query, event)
      expect(result.event&.piece).to eq(Piece[:white, :knight])
    end

    it 'resolves `from` when nil or partial' do
      [nil, Square[nil, nil], Square[:g, nil], Square[nil, 2]].each do |from|
        event = base_event.with(from: from)
        result = MoveEventHandler.call(start_query, event)
        expect(result.event&.from).to eq(Square[:g, 2])
      end
    end

    it 'resolved ambgiuity when there is enough information' do
      # For rooks at a1, a7
      base_event = MovePieceEvent[Piece[:white, :rook], nil, Square[:a, 3]]
      [Square[nil, 1], Square[nil, 7], Square[:a, 1]].each do |from|
        event = base_event.with(from: from)
        result = MoveEventHandler.call(white_query, event)
        expect(result).to be_a_successful_handler_result
      end
    end

    it 'resolves `captured` when partial' do
      base_event = MovePieceEvent[Piece[:white, :pawn], Square[:d, 5], Square[:c, 6]]
      [[nil, nil], [nil, Piece[:black, nil]], [nil, Piece[:black, :pawn]], [Square[nil, nil], Piece[nil, nil]],
       [Square[nil, 6], nil], [Square[:c, 6], Piece[nil, :pawn]]].each do |sq, p|
        event = base_event.capture(sq, p)
        result = MoveEventHandler.call(white_query, event)
        expect(result).to be_a_successful_handler_result
        expect(result.event.captured).to eq(CaptureData[Square[:c, 6], Piece[:black, :pawn]])
      end
    end

    it 'accepts legal promotion' do
      base_event = MovePieceEvent[Piece[:black, :pawn], Square[:h, 2], Square[:h, 1]].promote(:queen)
      result = MoveEventHandler.call(black_query, base_event)
      expect(result).to be_a_successful_handler_result
      expect(result.event.promote_to).to eq(:queen)
    end
  end
end
