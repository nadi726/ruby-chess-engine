# frozen_string_literal: true

require 'game_state/game_query'
require 'game_state/board'
require 'game_state/position'
require 'event_handlers/en_passant_event_handler'
require 'data_definitions/events'
require 'data_definitions/square'

RSpec.describe EnPassantEventHandler do
  let(:board) do
    start_board
      .move(Square[:e, 2], Square[:e, 5])
      .move(Square[:d, 7], Square[:d, 5])
  end

  let(:black_pawn_move) do
    MovePieceEvent[Square[:d, 7], Square[:d, 5], Piece[:black, :pawn]]
  end

  let(:move_history) do
    Immutable::List[black_pawn_move]
  end

  let(:query) do
    GameQuery.new(
      Position.start.with(
        board: board,
        en_passant_target: Square[:d, 6],
        current_color: :white
      ),
      move_history
    )
  end

  it 'accepts valid en passant' do
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_successful_handler_result
  end

  it 'rejects if given event is not en passant' do
    event = MovePieceEvent[nil, Square[:c, 2], Square[:c, 3]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if target square is not valid en passant target' do
    event = EnPassantEvent[nil, Square[:c, 2], Square[:c, 3]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if moving piece is not a pawn' do
    event = EnPassantEvent[Piece[:white, :knight], Square[:b, 1], Square[:a, 3]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if last move was not a double-step pawn move' do
    one_step_move = MovePieceEvent[Piece[:black, :pawn], Square[:d, 6], Square[:d, 5]]
    move_history = Immutable::List[one_step_move]
    query = GameQuery.new(
      Position.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      move_history
    )
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if not immediate (other move played in between)' do
    black_double_push = MovePieceEvent[Piece[:black, :pawn], Square[:d, 7], Square[:d, 5]]
    some_other_move = MovePieceEvent[Piece[:white, :bishop], Square[:c, 1], Square[:e, 3]]
    move_history = Immutable::List[black_double_push, some_other_move]
    query = GameQuery.new(
      Position.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      move_history
    )
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if it is not the right player’s turn' do
    query = GameQuery.new(
      Position.start.with(
        board: board,
        en_passant_target: Square[:d, 6],
        current_color: :black
      ),
      move_history
    )
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_failed_handler_result
  end

  it "doesn't put the moving player's king in check" do
    new_board = board.move(Square[:h, 8], Square[:e, 6])
    query = GameQuery.new(
      Position.start.with(
        board: new_board,
        en_passant_target: Square[:d, 6],
        current_color: :white
      ),
      move_history
    )
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event)
    expect(handler.process).to be_a_failed_handler_result
  end

  describe 'malformed events' do
    it 'rejects for an incorrect color' do
      event = EnPassantEvent[:black, Square[:e, 5], Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_failed_handler_result
    end

    it 'rejects for a valid but incorrect `from` square' do
      event = EnPassantEvent[nil, Square[:e, 4], Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_failed_handler_result
    end

    it 'rejects for a `from` square that is valid to en-passant from but currently has no pawn' do
      event = EnPassantEvent[nil, Square[:c, 5], Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_failed_handler_result
    end

    it 'rejects for an invalid from square' do
      event = EnPassantEvent[nil, Square[:x, 500], Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_failed_handler_result
    end

    it 'rejects for a valid but incorrect `to` square' do
      event = EnPassantEvent[nil, Square[:e, 5], Square[:g, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_failed_handler_result
    end

    it 'rejects for an invalid `to`' do
      event = EnPassantEvent[nil, Square[:e, 5], 5]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_failed_handler_result
    end

    it 'rejects when disambiguation fails (`from` not supplied)' do
      board = query.position.board.move(Square[:c, 2], Square[:c, 5])
      new_query = GameQuery.new(query.position.with(board: board), move_history)
      event = EnPassantEvent[nil, Square[nil, 5], Square[:d, 6]]
      handler = EnPassantEventHandler.new(new_query, event)
      expect(handler.process).to be_a_failed_handler_result
    end
  end

  describe 'incomplete but valid events' do
    it 'accepts when no color given' do
      event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_successful_handler_result
    end

    it 'accepts when no `from` square given and there is no ambiguity' do
      event = EnPassantEvent[:white, nil, Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_successful_handler_result
    end

    it 'accepts when `from` square gives just enough to solve ambiguity' do
      new_board = board.move(Square[:c, 2], Square[:c, 5])
      new_query = GameQuery.new(query.position.with(board: new_board), move_history)
      event = EnPassantEvent[nil, Square[:c, nil], Square[:d, 6]]
      handler = EnPassantEventHandler.new(new_query, event)
      expect(handler.process).to be_a_successful_handler_result
    end

    it 'accepts when `from` square is missing rank' do
      event = EnPassantEvent[nil, Square[:e, nil], Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_successful_handler_result
    end

    it 'accepts when `from` square is missing file' do
      event = EnPassantEvent[nil, Square[nil, 5], Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      expect(handler.process).to be_a_successful_handler_result
    end

    it 'resolves to the correct capture and piece positions' do
      event = EnPassantEvent[nil, nil, Square[:d, 6]]
      handler = EnPassantEventHandler.new(query, event)
      result = handler.process
      expect(result.event).to eq(EnPassantEvent[:white, Square[:e, 5], Square[:d, 6]])
    end
  end
end
