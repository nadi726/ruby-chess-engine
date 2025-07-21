# frozen_string_literal: true

require 'game_state/game_query'
require 'game_state/board'
require 'game_state/game_data'
require 'event_handlers/move_event_handler'
require 'data_definitions/events'
require 'data_definitions/position'

RSpec.describe MoveEventHandler do
  # A board & query setup used for most of the tests
  let(:board) do
    fill_board(
      # White pieces
      [
        [Piece[:white, :king], Position[:e, 1]],
        [Piece[:white, :rook],   Position[:a, 1]],
        [Piece[:white, :pawn],   Position[:d, 5]],
        [Piece[:white, :knight], Position[:b, 1]],
        # Black pieces
        [Piece[:black, :king],   Position[:e, 8]],
        [Piece[:black, :queen],  Position[:d, 8]],
        [Piece[:black, :pawn],   Position[:c, 6]],
        [Piece[:black, :rook],   Position[:h, 8]]
      ]
    )
  end

  let(:white_query) do
    GameQuery.new(GameData.start.with(board: board))
  end

  let(:black_query) do
    GameQuery.new(white_query.data.with(current_color: :black))
  end

  context 'move event' do
    it 'returns valid result for 1-rank pawn move' do
      main = MovePieceEvent[Position[:d, 2], Position[:d, 3], nil]
      handler = MoveEventHandler.new(start_query, main, [])
      expect(handler.handle).to be_a_successful_handler_result
    end

    it 'returns valid result for 2-rank pawn move' do
      main = MovePieceEvent[Position[:f, 2], Position[:f, 4], nil]
      handler = MoveEventHandler.new(start_query, main, [])
      expect(handler.handle).to be_a_successful_handler_result
    end

    it 'returns invalid result for 3-rank pawn move' do
      main = MovePieceEvent[Position[:g, 2], Position[:f, 5], nil]
      handler = MoveEventHandler.new(start_query, main, [])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'returns valid result for valid knight move' do
      main = MovePieceEvent[Position[:b, 1], Position[:c, 3], nil]
      handler = MoveEventHandler.new(start_query, main, [])
      expect(handler.handle).to be_a_successful_handler_result
    end
  end

  context 'for complex state' do
    it 'allows white rook to move to a5' do
      main = MovePieceEvent[Position[:a, 1], Position[:a, 5], nil]
      handler = MoveEventHandler.new(white_query, main, [])
      expect(handler.handle).to be_a_successful_handler_result
    end

    it 'prevents white pawn from moving to c6 (blocked by black pawn)' do
      event = MovePieceEvent[Position[:d, 5], Position[:c, 6], nil]
      handler = MoveEventHandler.new(white_query, event, [])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'allows white knight to jump to c3' do
      event = MovePieceEvent[Position[:b, 1], Position[:c, 3], nil]
      handler = MoveEventHandler.new(white_query, event, [])
      expect(handler.handle).to be_a_successful_handler_result
    end

    it 'prevents white rook from moving through black queen' do
      event = MovePieceEvent[Position[:a, 1], Position[:d, 8], nil]
      handler = MoveEventHandler.new(white_query, event, [])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'allows black queen to capture white pawn on d5 with empty remove event' do
      event = MovePieceEvent[Position[:d, 8], Position[:d, 5], nil]
      handler = MoveEventHandler.new(black_query, event, [RemovePieceEvent.new])
      expect(handler.handle).to be_a_successful_handler_result
    end

    it 'fails when capturing but no RemovePieceEvent is given' do
      event = MovePieceEvent[Position[:d, 8], Position[:d, 5], nil]
      handler = MoveEventHandler.new(black_query, event, [])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'prevents black rook from moving to a1 (blocked by white rook)' do
      event = MovePieceEvent[Position[:h, 8], Position[:a, 1], nil]
      handler = MoveEventHandler.new(black_query, event, [])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'fails when RemovePieceEvent position does not match the target square' do
      move = MovePieceEvent[Position[:d, 8], Position[:d, 5], nil]
      remove = RemovePieceEvent[Position[:c, 6], Piece[:white, :pawn]]
      handler = MoveEventHandler.new(black_query, move, [remove])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'fails when RemovePieceEvent piece is not actually at given position' do
      move = MovePieceEvent[Position[:d, 8], Position[:d, 5], nil]
      remove = RemovePieceEvent[Position[:d, 5], Piece[:white, :knight]]
      handler = MoveEventHandler.new(black_query, move, [remove])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'fails when moving from an empty square' do
      event = MovePieceEvent[Position[:c, 4], Position[:d, 5], nil]
      handler = MoveEventHandler.new(white_query, event, [])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'fails when trying to move onto allied piece even with RemovePieceEvent' do
      move = MovePieceEvent[Position[:a, 1], Position[:d, 5], nil]
      remove = RemovePieceEvent[Position[:d, 5], Piece[:white, :pawn]]
      handler = MoveEventHandler.new(white_query, move, [remove])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'fails if RemovePieceEvent is given but no piece is being captured' do
      move = MovePieceEvent[Position[:a, 1], Position[:a, 4], nil]
      remove = RemovePieceEvent[Position[:a, 4], nil]
      handler = MoveEventHandler.new(white_query, move, [remove])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'succeeds when a valid capture is declared correctly & fully' do
      move = MovePieceEvent[Position[:d, 8], Position[:d, 5], nil]
      captured = board.get(Position[:d, 5])
      remove = RemovePieceEvent[Position[:d, 5], captured]
      handler = MoveEventHandler.new(black_query, move, [remove])
      expect(handler.handle).to be_a_successful_handler_result
    end
  end

  context 'for another complex state' do
    let(:board) do
      fill_board(
        [
          [Piece[:white, :king], Position[:e, 1]],
          [Piece[:white, :rook],   Position[:a, 1]],
          [Piece[:white, :pawn],   Position[:d, 5]],
          [Piece[:white, :knight], Position[:b, 1]],
          [Piece[:white, :bishop], Position[:c, 1]],
          [Piece[:black, :king],   Position[:e, 8]],
          [Piece[:black, :queen],  Position[:d, 8]],
          [Piece[:black, :pawn],   Position[:a, 6]],
          [Piece[:black, :rook],   Position[:h, 8]],
          [Piece[:black, :bishop], Position[:f, 8]]
        ]
      )
    end
    let(:white_query) do
      GameQuery.new(GameData.start.with(board: board))
    end

    let(:black_state) do
      GameQuery.new(white_query.data.with(current_color: :black))
    end

    context 'friendly fire prevention' do
      it 'prevents moving onto a square occupied by own piece' do
        # White knight tries to move to c1 (occupied by white bishop)
        event = MovePieceEvent[Position[:b, 1], Position[:c, 1], nil]
        handler = MoveEventHandler.new(white_query, event, [])
        expect(handler.handle).to be_a_failed_handler_result
      end

      it 'prevents capturing own piece even with remove event' do
        # White rook tries to capture white pawn on d5
        move_event = MovePieceEvent[Position[:a, 1], Position[:d, 5], nil]
        remove_event = RemovePieceEvent[Position[:d, 5], Piece[:white, :pawn]]
        handler = MoveEventHandler.new(white_query, move_event, [remove_event])
        expect(handler.handle).to be_a_failed_handler_result
      end
    end

    context 'capture enforcement' do
      it 'requires remove event to capture opponent piece' do
        # White rook tries to capture black pawn on a6 without remove event
        event = MovePieceEvent[Position[:a, 1], Position[:a, 6], nil]
        handler = MoveEventHandler.new(white_query, event, [])
        expect(handler.handle).to be_a_failed_handler_result
      end

      it 'allows capture with correct remove event' do
        move_event = MovePieceEvent[Position[:a, 1], Position[:a, 6], nil]
        remove_event = RemovePieceEvent[Position[:a, 6], nil]
        handler = MoveEventHandler.new(white_query, move_event, [remove_event])
        expect(handler.handle).to be_a_successful_handler_result
      end
    end

    context 'bishop movement and path blocking' do
      it 'allows bishop to move diagonally unobstructed' do
        # Move white bishop from c1 to e3 (assuming clear path)
        event = MovePieceEvent[Position[:c, 1], Position[:e, 3], nil]
        handler = MoveEventHandler.new(white_query, event, [])
        expect(handler.handle).to be_a_successful_handler_result
      end

      it 'prevents bishop moving through piece blocking path' do
        # Place a piece blocking bishop at d2
        board_with_block = board.insert(Piece.new(:white, :pawn), Position[:d, 2])
        query_with_block = GameQuery.new(GameData.start.with(board: board_with_block))
        event = MovePieceEvent[Position[:c, 1], Position[:e, 3]]
        handler = MoveEventHandler.new(query_with_block, event, [])
        expect(handler.handle).to be_a_failed_handler_result
      end
    end

    context 'turn enforcement' do
      it 'prevents black from moving when it is white’s turn' do
        event = MovePieceEvent[Position[:e, 8], Position[:e, 7]]
        handler = MoveEventHandler.new(white_query, event, [])
        expect(handler.handle).to be_a_failed_handler_result
      end

      it 'allows black to move on black’s turn' do
        event = MovePieceEvent[Position[:e, 8], Position[:e, 7]]
        handler = MoveEventHandler.new(black_state, event, [])
        expect(handler.handle).to be_a_successful_handler_result
      end
    end
  end

  context 'en passant' do
    let(:black_pawn_move) do
      MovePieceEvent[Position[:d, 7], Position[:d, 5], Piece[:black, :pawn]]
    end

    let(:new_board) do
      fill_board(
        [
          [Piece[:white, :pawn], Position[:e, 5]],
          [Piece[:black, :pawn], Position[:d, 5]]
        ],
        board: board.remove(Position[:d, 5])
      )
    end

    let(:new_move_history) do
      white_query.move_history.add(Immutable::List[black_pawn_move])
    end

    let(:query) do
      GameQuery.new(
        GameData.start.with(board: new_board, en_passant_target: Position[:d, 6]),
        new_move_history
      )
    end
    it 'rejects en passant without required events' do
      # Attempt en passant without RemovePieceEvent
      move_event = MovePieceEvent[Position[:e, 5], Position[:d, 6]]
      handler = MoveEventHandler.new(query, move_event, [])
      expect(handler.handle).to be_a_failed_handler_result
    end

    it 'accept en passant with required events from move event' do
      move_event = MovePieceEvent[Position[:e, 5], Position[:d, 6]]
      handler = MoveEventHandler.new(query, move_event, [RemovePieceEvent.new])
      expect(handler.handle).to be_a_successful_handler_result
    end
  end
end
