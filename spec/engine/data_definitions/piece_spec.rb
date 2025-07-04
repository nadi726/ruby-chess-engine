# frozen_string_literal: true

require 'data_definitions/piece'
require 'data_definitions/position'

# Fills a GameState double with stubbed `piece_at` responses, given an array of
# positions for white and black pieces.
#
# - All positions not listed return nil
# - Each position for white pieces returns a double with color: :white
# - Each position for black pieces returns a double with color: :black
def fill_state(state, white_positions, black_positions) # rubocop:disable Metrics/AbcSize
  # All other positions return nil
  allow(state).to receive(:piece_at).and_return(nil)

  # Set up white pieces
  Array(white_positions).each do |pos|
    allow(state).to receive(:piece_at).with(pos).and_return(double('Piece', color: :white))
  end

  # Set up black pieces
  Array(black_positions).each do |pos|
    allow(state).to receive(:piece_at).with(pos).and_return(double('Piece', color: :black))
  end
end

describe Piece do
  describe '#moves' do
    context 'for king' do
      subject(:king) { Piece.new(:white, :king, Position.new(:e, 1)) }

      it 'produces correct positions from starting position' do
        expect(king.moves).to match_array(parse_positions('d1 d2 e2 f1 f2'))
      end

      it 'produces correct positions from a central position' do
        king.position = Position.new(:d, 4)
        expect(king.moves).to match_array(parse_positions('c3 c4 c5 d3 d5 e3 e4 e5'))
      end

      it 'produces correct positions from a corner' do
        king.position = Position.new(:a, 1)
        expect(king.moves).to match_array(parse_positions('a2 b1 b2'))
      end
    end

    context 'for queen' do
      subject(:queen) { Piece.new(:black, :queen, Position.new(:d, 8)) }

      it 'produces correct positions from starting position' do
        positions = parse_positions('a8 b8 c8 e8 f8 g8 h8 d7 d6 d5 d4 d3 d2 d1 c7 b6 a5 e7 f6 g5 h4')
        expect(queen.moves).to match_array(positions)
      end

      it 'produces correct positions from a central position' do
        queen.position = Position.new(:f, 5)
        positions = parse_positions('a5 b5 c5 d5 e5 g5 h5 f1 f2 f3 f4 f6 f7 f8 h7 g6 e4 d3 c2 b1 c8 d7 e6 g4 h3')
        expect(queen.moves).to match_array(positions)
      end

      it 'produces correct positions from a corner' do
        queen.position = Position.new(:a, 8)
        positions = parse_positions('a1 a2 a3 a4 a5 a6 a7 b8 c8 d8 e8 f8 g8 h8 b7 c6 d5 e4 f3 g2 h1')
        expect(queen.moves).to match_array(positions)
      end
    end

    context 'for rook' do
      subject(:rook) { Piece.new(:white, :rook, Position.new(:h, 1)) }

      it 'produces correct positions from a central position' do
        rook.position = Position.new(:c, 3)
        positions = parse_positions('c1 c2 c4 c5 c6 c7 c8 a3 b3 d3 e3 f3 g3 h3')
        expect(rook.moves).to match_array(positions)
      end

      it 'produces correct positions from a corner' do
        positions = parse_positions('h2 h3 h4 h5 h6 h7 h8 a1 b1 c1 d1 e1 f1 g1')
        expect(rook.moves).to match_array(positions)
      end
    end

    context 'for bishop' do
      subject(:bishop) { Piece.new(:black, :bishop, Position.new(:c, 1)) }

      it 'produces correct positions from c1' do
        expect(bishop.moves).to match_array(parse_positions('b2 a3 d2 e3 f4 g5 h6'))
      end

      it 'produces correct positions from center' do
        bishop.position = Position.new(:d, 4)
        expected_positions = parse_positions('a1 b2 c3 e5 f6 g7 h8 a7 b6 c5 e3 f2 g1')
        expect(bishop.moves).to match_array(expected_positions)
      end

      it 'produces correct positions for corner' do
        bishop.position = Position.new(:a, 8)
        expected_positions = parse_positions('b7 c6 d5 e4 f3 g2 h1')
        expect(bishop.moves).to match_array(expected_positions)
      end
    end

    context 'for knight' do
      subject(:knight) { Piece.new(:white, :knight, Position.new(:b, 1)) }

      it 'produces correct positions from a central position' do
        knight.position = Position.new(:e, 3)
        expect(knight.moves).to match_array(parse_positions('c2 c4 d1 f1 g2 g4 f5 d5'))
      end

      it 'produces correct positions from a corner' do
        knight.position = Position.new(:h, 1)
        expect(knight.moves).to match_array(parse_positions('g3 f2'))
      end
    end

    context 'for black pawn' do
      subject(:black_pawn) { Piece.new(:black, :pawn, Position.new(:d, 7)) }

      it 'can move both 1 and 2 steps from starting position' do
        expect(black_pawn.moves).to match_array(parse_positions('d6 d5'))
      end

      it 'can move only 1 step from non-starting position' do
        black_pawn.position = Position.new(:d, 6)
        expect(black_pawn.moves).to match_array(parse_positions('d5'))
      end

      it 'has no moves when on the promotion rank' do
        black_pawn.position = Position.new(:d, 1)
        expect(black_pawn.moves).to match_array([])
      end
    end

    context 'for white pawn' do
      subject(:white_pawn) { Piece.new(:white, :pawn, Position.new(:f, 2)) }

      it 'can move both 1 and 2 steps from starting position' do
        expect(white_pawn.moves).to match_array(parse_positions('f3 f4'))
      end

      it 'can move only 1 step from non-starting position' do
        white_pawn.position = Position.new(:f, 6)
        expect(white_pawn.moves).to match_array(parse_positions('f7'))
      end
    end

    context 'with state' do
      let(:state) { double('GameState') }

      before do
        allow(state).to receive(:piece_at)
      end

      context 'with no blocking pieces' do
        it 'pawn can move both 1 and 2 steps from starting position' do
          black_pawn = Piece.new(:black, :pawn, Position.new(:d, 7))
          expect(black_pawn.moves(state: state)).to match_array(black_pawn.moves)
        end

        it 'produces correct positions from center' do
          bishop = Piece.new(:black, :bishop, Position.new(:d, 4))
          expect(bishop.moves(state: state)).to match_array(bishop.moves)
        end
      end

      it 'white queen surrounded by friendly pieces' do
        fill_state(state, parse_positions('c1 c2 d2 e1 e2'), [])
        queen = Piece.new(:white, :queen, Position.new(:d, 1))
        expect(queen.moves(state: state)).to match_array([])
      end

      it 'queen can move until blocked' do
        fill_state(state, parse_positions('c1'), parse_positions('d3'))
        queen = Piece.new(:white, :queen, Position.new(:d, 1))
        expected = parse_positions('d2 e1 f1 g1 h1 c2 b3 a4 e2 f3 g4 h5')
        expect(queen.moves(state: state)).to match_array(expected)
      end

      it 'rook can move until blocked' do
        fill_state(state, parse_positions('b1'), parse_positions('a7 a8'))
        rook = Piece.new(:white, :rook, Position.new(:a, 1))
        expected = parse_positions 'a2 a3 a4 a5 a6'
        expect(rook.moves(state: state)).to match_array(expected)
      end

      it 'white pawn blocked ahead but can capture diagonally' do
        fill_state(state, [], parse_positions('e3 g3 f3'))
        pawn = Piece.new(:white, :pawn, Position.new(:f, 2))
        expect(pawn.moves(state: state)).to match_array([])
      end

      it 'knight can jump over pieces' do
        fill_state(state, parse_positions('e2 d3'), parse_positions('f3'))
        knight = Piece.new(:white, :knight, Position.new(:e, 1))
        expected = parse_positions('c2 g2')
        expect(knight.moves(state: state)).to match_array(expected)
      end
    end
  end

  describe '#threatened_squares' do
    context 'for pawn' do
      it 'produces correct positions for white pawn at f2' do
        pawn = Piece.new(:white, :pawn, Position.new(:f, 2))
        expect(pawn.threatened_squares).to match_array(parse_positions('e3 g3'))
      end
      it 'produces correct positions for white pawn at h2' do
        pawn = Piece.new(:white, :pawn, Position.new(:h, 2))
        expect(pawn.threatened_squares).to match_array(parse_positions('g3'))
      end

      it 'produces correct positions for white pawn at a7' do
        pawn = Piece.new(:white, :pawn, Position.new(:a, 7))
        expect(pawn.threatened_squares).to match_array(parse_positions('b8'))
      end

      it 'produces correct positions for black pawn at d6' do
        pawn = Piece.new(:black, :pawn, Position.new(:d, 6))
        expect(pawn.threatened_squares).to match_array(parse_positions('c5 e5'))
      end
    end

    context 'for other pieces' do
      it 'produces the same positions as move positions for white king ' do
        king = Piece.new(:white, :king, Position.new(:e, 1))
        expect(king.threatened_squares).to match_array(king.moves)
      end

      it 'produces the same positions as move positions for black rook' do
        rook = Piece.new(:black, :rook, Position.new(:c, 1))
        expect(rook.threatened_squares).to match_array(rook.moves)
      end
    end

    context 'with state' do
      let(:state) { double('GameState') }

      before do
        allow(state).to receive(:piece_at).and_return(nil)
      end

      it 'bishop can attack enemy piece but not friendly piece' do
        bishop = Piece.new(:white, :bishop, Position.new(:c, 1))
        fill_state(state, parse_positions('g5'), parse_positions('a3'))
        expected = parse_positions('b2 a3 d2 e3 f4 g5')
        expect(bishop.threatened_squares(state: state)).to match_array(expected)
      end

      it 'queen attacks include both empty and enemy-occupied squares' do
        queen = Piece.new(:white, :queen, Position.new(:d, 1))
        fill_state(state, [], parse_positions('d3 f1'))
        expected = parse_positions('d2 d3 e1 f1 a1 b1 c1 c2 b3 a4 e2 f3 g4 h5')
        expect(queen.threatened_squares(state: state)).to match_array(expected)
      end

      it 'rook does not attack beyond a blocking piece' do
        rook = Piece.new(:black, :rook, Position.new(:a, 1))
        fill_state(state, parse_positions('a6 a7 a8'), parse_positions('a3'))
        expected = parse_positions('a2 a3 b1 c1 d1 e1 f1 g1 h1') # stops at friendly piece at a3
        expect(rook.threatened_squares(state: state)).to match_array(expected)
      end

      it 'knight attacks are unaffected by surrounding pieces' do
        knight = Piece.new(:white, :knight, Position.new(:e, 1))
        fill_state(state, parse_positions('d3'), parse_positions('f3'))
        expected = parse_positions('c2 g2 f3 d3') # knight can jump over
        expect(knight.threatened_squares(state: state)).to match_array(expected)
      end

      it 'pawn attacks empty squares and enemy diagonals only' do
        pawn = Piece.new(:white, :pawn, Position.new(:f, 2))
        fill_state(state, [], parse_positions('e3'))
        expect(pawn.threatened_squares(state: state)).to match_array(parse_positions('e3 g3'))
      end

      it 'pawn attacks friendly diagonals as well (geometry only)' do
        pawn = Piece.new(:white, :pawn, Position.new(:f, 2))
        fill_state(state, parse_positions('e3 g3'), [])
        expect(pawn.threatened_squares(state: state)).to match_array(parse_positions('e3 g3'))
      end
    end
  end
end
