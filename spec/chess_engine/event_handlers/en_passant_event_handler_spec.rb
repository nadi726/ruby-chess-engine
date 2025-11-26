# frozen_string_literal: true

RSpec.describe EventHandlers::EnPassantEventHandler do
  let(:klass) { described_class }
  let(:board) do
    start_board
      .move(Square[:e, 2], Square[:e, 5])
      .move(Square[:d, 7], Square[:d, 5])
  end

  let(:black_pawn_move) do
    MovePieceEvent[Square[:d, 7], Square[:d, 5], Piece[:black, :pawn]]
  end

  let(:history) do
    Game::History.start.with(moves: Immutable::List[black_pawn_move])
  end

  let(:query) do
    Game::Query.new(
      Position.start.with(
        board: board,
        en_passant_target: Square[:d, 6],
        current_color: :white
      ),
      history
    )
  end

  it 'accepts valid en passant' do
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    result = klass.call(query, event)
    expect(result).to be_a_successful_handler_result
  end

  it 'rejects if given event is not en passant' do
    event = MovePieceEvent[nil, Square[:c, 2], Square[:c, 3]]
    result = klass.call(query, event)
    expect(result).to be_a_failed_handler_result
  end

  it 'rejects if target square is not valid en passant target' do
    event = EnPassantEvent[nil, Square[:c, 2], Square[:c, 3]]
    result = klass.call(query, event)
    expect(result).to be_a_failed_handler_result
  end

  it 'rejects if moving piece is not a pawn' do
    event = EnPassantEvent[Piece[:white, :knight], Square[:b, 1], Square[:a, 3]]
    result = klass.call(query, event)
    expect(result).to be_a_failed_handler_result
  end

  it 'rejects if last move was not a double-step pawn move' do
    one_step_move = MovePieceEvent[Piece[:black, :pawn], Square[:d, 6], Square[:d, 5]]
    query = Game::Query.new(
      Position.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      Game::History.start.with(moves: [one_step_move])
    )
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    result = klass.call(query, event)
    expect(result).to be_a_failed_handler_result
  end

  it 'rejects if not immediate (other move played in between)' do
    black_double_push = MovePieceEvent[Piece[:black, :pawn], Square[:d, 7], Square[:d, 5]]
    some_other_move = MovePieceEvent[Piece[:white, :bishop], Square[:c, 1], Square[:e, 3]]
    query = Game::Query.new(
      Position.start.with(
        board: board,
        en_passant_target: nil,
        current_color: :white
      ),
      Game::History.start.with(moves: [black_double_push, some_other_move])
    )
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    result = klass.call(query, event)
    expect(result).to be_a_failed_handler_result
  end

  it 'rejects if it is not the right player’s turn' do
    new_query = query.with(position: Position.start.with(
      board: board,
      en_passant_target: Square[:d, 6],
      current_color: :black
    ))

    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    result = klass.call(new_query, event)
    expect(result).to be_a_failed_handler_result
  end

  it "doesn't put the moving player's king in check" do
    new_board = board.move(Square[:h, 8], Square[:e, 6])
    new_query = query.with(
      position: Position.start.with(
        board: new_board,
        en_passant_target: Square[:d, 6],
        current_color: :white
      )
    )
    event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
    result = klass.call(new_query, event)
    expect(result).to be_a_failed_handler_result
  end

  describe 'malformed events' do
    it 'rejects for an incorrect color' do
      event = EnPassantEvent[:black, Square[:e, 5], Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'rejects for a valid but incorrect `from` square' do
      event = EnPassantEvent[nil, Square[:e, 4], Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'rejects for a `from` square that is valid to en-passant from but currently has no pawn' do
      event = EnPassantEvent[nil, Square[:c, 5], Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'rejects for an invalid from square' do
      event = EnPassantEvent[nil, Square[:x, 500], Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'rejects for a valid but incorrect `to` square' do
      event = EnPassantEvent[nil, Square[:e, 5], Square[:g, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'rejects for an invalid `to`' do
      event = EnPassantEvent[nil, Square[:e, 5], 5]
      result = klass.call(query, event)
      expect(result).to be_a_failed_handler_result
    end

    it 'rejects when disambiguation fails (`from` not supplied)' do
      board = query.board.move(Square[:c, 2], Square[:c, 5])
      new_query = query.with(position: query.position.with(board: board))
      event = EnPassantEvent[nil, Square[nil, 5], Square[:d, 6]]
      result = klass.call(new_query, event)
      expect(result).to be_a_failed_handler_result
    end
  end

  describe 'incomplete but valid events' do
    it 'accepts when no color given' do
      event = EnPassantEvent[nil, Square[:e, 5], Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'accepts when no `from` square given and there is no ambiguity' do
      event = EnPassantEvent[:white, nil, Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'accepts when `from` square gives just enough to solve ambiguity' do
      new_board = board.move(Square[:c, 2], Square[:c, 5])
      new_query = query.with(position: query.position.with(board: new_board))
      event = EnPassantEvent[nil, Square[:c, nil], Square[:d, 6]]
      result = klass.call(new_query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'accepts when `from` square is missing rank' do
      event = EnPassantEvent[nil, Square[:e, nil], Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'accepts when `from` square is missing file' do
      event = EnPassantEvent[nil, Square[nil, 5], Square[:d, 6]]
      result = klass.call(query, event)
      expect(result).to be_a_successful_handler_result
    end

    it 'resolves to the correct capture and piece positions' do
      event = EnPassantEvent[nil, nil, Square[:d, 6]]
      result = klass.call(query, event)
      expect(result.event).to eq(EnPassantEvent[:white, Square[:e, 5], Square[:d, 6]])
    end
  end
end
