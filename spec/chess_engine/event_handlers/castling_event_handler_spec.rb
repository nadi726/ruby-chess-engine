# frozen_string_literal: true

RSpec.describe EventHandlers::CastlingEventHandler do
  let(:klass) { described_class }
  let(:board) do
    fill_board([
                 [Piece[:white, :rook], Square[:a, 1]],
                 [Piece[:white, :king], Square[:e, 1]],
                 [Piece[:white, :rook], Square[:h, 1]],
                 [Piece[:black, :rook], Square[:a, 8]],
                 [Piece[:black, :king], Square[:e, 8]],
                 [Piece[:black, :rook], Square[:h, 8]]
               ])
  end

  let(:white_query) { Game::Query.new(Position.start.with(board: board, current_color: :white)) }
  let(:black_query) { Game::Query.new(Position.start.with(board: board, current_color: :black)) }

  def create_query(board, color, rights: CastlingRights.start)
    Game::Query.new(Position.start.with(board: board, current_color: color, castling_rights: rights))
  end

  describe 'move logic' do
    context 'with no color in check' do
      CastlingData::SIDES.product(Colors::COLORS).each do |side, color|
        it "accepts for #{color} #{side}" do
          query = color == :white ? white_query : black_query
          event = CastlingEvent[color, side]
          result = klass.call(query, event)
          expect(result).to be_a_successful_handler_result
          expect(result.event).to eq(event)
        end
      end
    end

    context 'with attacks' do
      it 'rejects when king is in check' do
        new_board = board.insert(Piece[:white, :bishop], Square[:a, 4])
        query = create_query(new_board, :black)
        CastlingData::SIDES.each do |side|
          result = klass.call(query, CastlingEvent[:black, side])
          expect(result).to be_a_failed_handler_result
        end
      end

      it 'rejects when a square the king is moving through is attacked (kingside)' do
        new_board = board.insert(Piece[:black, :knight], Square[:g, 3])
        query = create_query(new_board, :white)
        event = CastlingEvent[:white, :kingside]
        expect(klass.call(query, event)).to be_a_failed_handler_result
      end

      it 'rejects when a square the king is moving through is attacked (queenside)' do
        new_board = board.insert(Piece[:white, :rook], Square[:d, 5])
        query = create_query(new_board, :black)
        event = CastlingEvent[:black, :queenside]
        expect(klass.call(query, event)).to be_a_failed_handler_result
      end
      it 'rejects when castling into check' do
        new_board = board.insert(Piece[:black, :bishop], Square[:a, 7])
        query = create_query(new_board, :white)
        event = CastlingEvent[:white, :kingside]
        expect(klass.call(query, event)).to be_a_failed_handler_result
      end
    end
    it 'rejects when there are no castling rights' do
      query = create_query(board, :black, rights: CastlingRights.none)
      CastlingData::SIDES.each do |side|
        event = CastlingEvent[:black, side]
        expect(klass.call(query, event)).to be_a_failed_handler_result
      end
    end
  end
  it "rejects when there's a piece between the king and the rook" do
    new_board = board.insert(Piece[:white, :bishop], Square[:f, 1])
    query = create_query(new_board, :white)
    event = CastlingEvent[:white, :kingside]
    expect(klass.call(query, event)).to be_a_failed_handler_result
  end

  describe 'malformed and incomplete events' do
    it 'rejects for an invalid color' do
      [5, :symbol, :black].each do |color|
        CastlingData::SIDES.each do |side|
          event = CastlingEvent[color, side]
          expect(klass.call(white_query, event)).to be_a_failed_handler_result
        end
      end
    end
    it 'rejects for an invalid side' do
      [nil, 'kingside', :side].each do |side|
        Colors.each do |color|
          query = create_query(board, color)
          event = CastlingEvent[color, side]
          expect(klass.call(query, event)).to be_a_failed_handler_result
        end
      end
    end
    it 'accepts when no color given' do
      CastlingData::SIDES.product(Colors::COLORS).each do |side, color|
        query = create_query(board, color)
        event = CastlingEvent[nil, side]
        result = klass.call(query, event)
        expect(result).to be_a_successful_handler_result
        expect(result.event).to eq(CastlingEvent[color, side])
      end
    end
  end
end
