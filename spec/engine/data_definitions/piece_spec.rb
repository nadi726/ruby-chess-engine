require 'data_definitions/piece'
require 'data_definitions/position'

# Expects an array of strings represnting a position(e.g. 'a1', 'd6')
# And returns an array of Position objects
def make_positions(positions)
  positions.split.map do |pos|
    Position.new(pos[0].to_sym, pos[1].to_i)
  end
end

describe Piece do
  describe '#moves' do
    context 'for king' do
      subject(:king) { Piece.new(:white, :king, Position.new(:e, 1)) }

      it 'produces correct positions from starting position' do
        expect(king.moves).to match_array(make_positions('d1 d2 e2 f1 f2'))
      end

      it 'produces correct positions from a central position' do
        king.position = Position.new(:d, 4)
        expect(king.moves).to match_array(make_positions('c3 c4 c5 d3 d5 e3 e4 e5'))
      end

      it 'produces correct positions from a corner' do
        king.position = Position.new(:a, 1)
        expect(king.moves).to match_array(make_positions('a2 b1 b2'))
      end
    end

    context 'for queen' do
      subject(:queen) { Piece.new(:black, :queen, Position.new(:d, 8)) }

      it 'produces correct positions from starting position' do
        positions = make_positions('a8 b8 c8 e8 f8 g8 h8 d7 d6 d5 d4 d3 d2 d1 c7 b6 a5 e7 f6 g5 h4')
        expect(queen.moves).to match_array(positions)
      end

      it 'produces correct positions from a central position' do
        queen.position = Position.new(:f, 5)
        positions = make_positions('a5 b5 c5 d5 e5 g5 h5 f1 f2 f3 f4 f6 f7 f8 h7 g6 e4 d3 c2 b1 c8 d7 e6 g4 h3')
        expect(queen.moves).to match_array(positions)
      end

      it 'produces correct positions from a corner' do
        queen.position = Position.new(:a, 8)
        positions = make_positions('a1 a2 a3 a4 a5 a6 a7 b8 c8 d8 e8 f8 g8 h8 b7 c6 d5 e4 f3 g2 h1')
        expect(queen.moves).to match_array(positions)
      end
    end

    context 'for rook' do
      subject(:rook) { Piece.new(:white, :rook, Position.new(:h, 1)) }

      it 'produces correct positions from a central position' do
        rook.position = Position.new(:c, 3)
        positions = make_positions('c1 c2 c4 c5 c6 c7 c8 a3 b3 d3 e3 f3 g3 h3')
        expect(rook.moves).to match_array(positions)
      end

      it 'produces correct positions from a corner' do
        positions = make_positions('h2 h3 h4 h5 h6 h7 h8 a1 b1 c1 d1 e1 f1 g1')
        expect(rook.moves).to match_array(positions)
      end
    end

    context 'for bishop' do
      subject(:bishop) { Piece.new(:black, :bishop, Position.new(:c, 1)) }

      it 'produces correct positions from c1' do
        expect(bishop.moves).to match_array(make_positions('b2 a3 d2 e3 f4 g5 h6'))
      end

      it 'produces correct positions from center' do
        bishop.position = Position.new(:d, 4)
        expected_positions = make_positions('a1 b2 c3 e5 f6 g7 h8 a7 b6 c5 e3 f2 g1')
        expect(bishop.moves).to match_array(expected_positions)
      end

      it 'produces correct positions for corner' do
        bishop.position = Position.new(:a, 8)
        expected_positions = make_positions('b7 c6 d5 e4 f3 g2 h1')
        expect(bishop.moves).to match_array(expected_positions)
      end
    end

    context 'for knight' do
      subject(:knight) { Piece.new(:white, :knight, Position.new(:b, 1)) }

      it 'produces correct positions from a central position' do
        knight.position = Position.new(:e, 3)
        expect(knight.moves).to match_array(make_positions('c2 c4 d1 f1 g2 g4 f5 d5'))
      end

      it 'produces correct positions from a corner' do
        knight.position = Position.new(:h, 1)
        expect(knight.moves).to match_array(make_positions('g3 f2'))
      end
    end

    context 'for black pawn' do
      subject(:black_pawn) { Piece.new(:black, :pawn, Position.new(:d, 7)) }
    end

    context 'for white pawn' do
      subject(:white_pawn) { Piece.new(:white, :pawn, Position.new(:f, 2)) }
    end
  end
end
