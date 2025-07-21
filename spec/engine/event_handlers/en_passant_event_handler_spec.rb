# frozen_string_literal: true

require 'game_state/game_query'
require 'game_state/board'
require 'game_state/game_data'
require 'event_handlers/en_passant_event_handler'
require 'data_definitions/events'
require 'data_definitions/position'

RSpec.describe EnPassantEventHandler do
  let(:board) do
    start_board
      .move(Position[:e, 2], Position[:e, 5])
      .move(Position[:d, 7], Position[:d, 5])
  end

  let(:black_pawn_move) do
    MovePieceEvent[Position[:d, 7], Position[:d, 5], Piece[:black, :pawn]]
  end

  let(:move_history) do
    Immutable::List[Immutable::List[black_pawn_move]]
  end

  let(:query) do
    GameQuery.new(
      GameData.start.with(
        board: board,
        en_passant_target: Position[:d, 6],
        current_color: :white
      ),
      move_history
    )
  end

  it 'accepts valid en passant' do
    event = EnPassantEvent[Position[:e, 5], Position[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.handle).to be_a_successful_handler_result
  end

  it 'rejects if given event is not en passant' do
    event = MovePieceEvent[Position[:c, 2], Position[:c, 3], nil]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.handle).to be_a_failed_handler_result
  end

  it 'rejects if target position is not valid en passant target' do
    event = EnPassantEvent[Position[:c, 2], Position[:c, 3]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.handle).to be_a_failed_handler_result
  end

  it 'rejects if moving piece is not a pawn' do
    event = EnPassantEvent[Position[:b, 1], Position[:a, 3]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.handle).to be_a_failed_handler_result
  end

  it 'rejects if last move was not a double-step pawn move' do
    one_step_move = MovePieceEvent[Position[:d, 6], Position[:d, 5], Piece[:black, :pawn]]
    move_history = Immutable::List[Immutable::List[one_step_move]]
    query = GameQuery.new(
      GameData.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      move_history
    )
    event = EnPassantEvent[Position[:e, 5], Position[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.handle).to be_a_failed_handler_result
  end

  it 'rejects if not immediate (other move played in between)' do
    black_double_push = MovePieceEvent[Position[:d, 7], Position[:d, 5], Piece[:black, :pawn]]
    some_other_move = MovePieceEvent[Position[:c, 1], Position[:e, 3], Piece[:white, :bishop]]
    move_history = Immutable::List[Immutable::List[black_double_push], Immutable::List[some_other_move]]
    query = GameQuery.new(
      GameData.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      move_history
    )
    event = EnPassantEvent[Position[:e, 5], Position[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.handle).to be_a_failed_handler_result
  end

  it 'rejects if it is not the right player’s turn' do
    query = GameQuery.new(
      GameData.start.with(
        board: board,
        en_passant_target: Position[:d, 6],
        current_color: :black
      ),
      move_history
    )
    event = EnPassantEvent[Position[:e, 5], Position[:d, 6]]
    handler = EnPassantEventHandler.new(query, event, [])
    expect(handler.handle).to be_a_failed_handler_result
  end
end
