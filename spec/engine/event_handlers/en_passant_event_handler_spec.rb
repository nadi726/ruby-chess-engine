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
    Immutable::List[Immutable::List[black_pawn_move]]
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
    event = EnPassantEvent[Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.process).to be_a_successful_handler_result
  end

  it 'rejects if given event is not en passant' do
    event = MovePieceEvent[Square[:c, 2], Square[:c, 3], nil]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if target square is not valid en passant target' do
    event = EnPassantEvent[Square[:c, 2], Square[:c, 3]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if moving piece is not a pawn' do
    event = EnPassantEvent[Square[:b, 1], Square[:a, 3]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if last move was not a double-step pawn move' do
    one_step_move = MovePieceEvent[Square[:d, 6], Square[:d, 5], Piece[:black, :pawn]]
    move_history = Immutable::List[Immutable::List[one_step_move]]
    query = GameQuery.new(
      Position.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      move_history
    )
    event = EnPassantEvent[Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.process).to be_a_failed_handler_result
  end

  it 'rejects if not immediate (other move played in between)' do
    black_double_push = MovePieceEvent[Square[:d, 7], Square[:d, 5], Piece[:black, :pawn]]
    some_other_move = MovePieceEvent[Square[:c, 1], Square[:e, 3], Piece[:white, :bishop]]
    move_history = Immutable::List[Immutable::List[black_double_push], Immutable::List[some_other_move]]
    query = GameQuery.new(
      Position.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      move_history
    )
    event = EnPassantEvent[Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
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
    event = EnPassantEvent[Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
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
    event = EnPassantEvent[Square[:e, 5], Square[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.process).to be_a_failed_handler_result
  end
end
