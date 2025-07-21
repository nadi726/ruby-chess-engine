# frozen_string_literal: true

require 'data_definitions/piece'
require 'data_definitions/position'
require 'game_state/board'

describe Piece do
  let(:empty_board) { Board.from_flat_array Array.new(64) }

  describe '#moves' do
    context 'for king' do
      subject(:king) { Piece[:white, :king] }
      it 'produces correct positions from starting position' do
        expect(king.moves(empty_board, Position[:e, 1])).to match_array(parse_positions('d1 d2 e2 f1 f2'))
      end

      it 'produces correct positions from a central position' do
        expect(king.moves(empty_board, Position[:d, 4])).to match_array(parse_positions('c3 c4 c5 d3 d5 e3 e4 e5'))
      end

      it 'produces correct positions from a corner' do
        expect(king.moves(empty_board, Position[:a, 1])).to match_array(parse_positions('a2 b1 b2'))
      end
    end

    context 'for queen' do
      subject(:queen) { Piece[:black, :queen] }

      it 'produces correct positions from starting position' do
        expect(
          queen.moves(empty_board, Position[:d, 8])
        ).to match_array(parse_positions('a8 b8 c8 e8 f8 g8 h8 d7 d6 d5 d4 d3 d2 d1 c7 b6 a5 e7 f6 g5 h4'))
      end

      it 'produces correct positions from a central position' do
        expect(
          queen.moves(empty_board, Position[:f, 5])
        ).to match_array(parse_positions('a5 b5 c5 d5 e5 g5 h5 f1 f2 f3 f4 f6 f7 f8 h7 g6 e4 d3 c2 b1 c8 d7 e6 g4 h3'))
      end

      it 'produces correct positions from a corner' do
        expect(
          queen.moves(empty_board, Position[:a, 8])
        ).to match_array(parse_positions('a1 a2 a3 a4 a5 a6 a7 b8 c8 d8 e8 f8 g8 h8 b7 c6 d5 e4 f3 g2 h1'))
      end
    end

    context 'for rook' do
      subject(:rook) { Piece[:white, :rook] }

      it 'produces correct positions from a central position' do
        positions = parse_positions('c1 c2 c4 c5 c6 c7 c8 a3 b3 d3 e3 f3 g3 h3')
        expect(rook.moves(empty_board, Position[:c, 3])).to match_array(positions)
      end

      it 'produces correct positions from a corner' do
        positions = parse_positions('h2 h3 h4 h5 h6 h7 h8 a1 b1 c1 d1 e1 f1 g1')
        expect(rook.moves(empty_board, Position[:h, 1])).to match_array(positions)
      end
    end

    context 'for bishop' do
      subject(:bishop) { Piece[:black, :bishop] }

      it 'produces correct positions from c1' do
        expect(bishop.moves(empty_board, Position[:c, 1])).to match_array(parse_positions('b2 a3 d2 e3 f4 g5 h6'))
      end

      it 'produces correct positions from center' do
        expected_positions = parse_positions('a1 b2 c3 e5 f6 g7 h8 a7 b6 c5 e3 f2 g1')
        expect(bishop.moves(empty_board, Position[:d, 4])).to match_array(expected_positions)
      end

      it 'produces correct positions for corner' do
        expected_positions = parse_positions('b7 c6 d5 e4 f3 g2 h1')
        expect(bishop.moves(empty_board, Position[:a, 8])).to match_array(expected_positions)
      end
    end

    context 'for knight' do
      subject(:knight) { Piece[:white, :knight] }

      it 'produces correct positions from a central position' do
        expect(knight.moves(empty_board,
                            Position[:e, 3])).to match_array(parse_positions('c2 c4 d1 f1 g2 g4 f5 d5'))
      end

      it 'produces correct positions from a corner' do
        expect(knight.moves(empty_board, Position[:h, 1])).to match_array(parse_positions('g3 f2'))
      end
    end

    context 'for black pawn' do
      subject(:black_pawn) { Piece[:black, :pawn] }

      it 'can move both 1 and 2 steps from starting position' do
        expect(black_pawn.moves(empty_board, Position[:d, 7])).to match_array(parse_positions('d6 d5'))
      end

      it 'can move only 1 step from non-starting position' do
        expect(black_pawn.moves(empty_board, Position[:d, 6])).to match_array(parse_positions('d5'))
      end

      it 'has no moves when on the promotion rank' do
        expect(black_pawn.moves(empty_board, Position[:d, 1])).to match_array([])
      end
    end

    context 'for white pawn' do
      subject(:white_pawn) { Piece[:white, :pawn] }

      it 'can move both 1 and 2 steps from starting position' do
        expect(white_pawn.moves(empty_board, Position[:f, 2])).to match_array(parse_positions('f3 f4'))
      end

      it 'can move only 1 step from non-starting position' do
        expect(white_pawn.moves(empty_board, Position[:f, 6])).to match_array(parse_positions('f7'))
      end
    end

    context 'with non-empty board' do
      let(:state) { double('GameState') }

      before do
        allow(state).to receive(:piece_at)
      end

      context 'with no blocking pieces' do
        it 'pawn can move both 1 and 2 steps from starting position' do
          black_pawn = Piece[:black, :pawn]
          expect(black_pawn.moves(start_board,
                                  Position.new(:d,
                                               7))).to match_array(black_pawn.moves(empty_board,
                                                                                    Position[:d, 7]))
        end
      end

      it 'white queen surrounded by friendly pieces' do
        board = fill_board_by_position(parse_positions('c1 c2 d2 e1 e2'), [])
        queen = Piece[:white, :queen]
        expect(queen.moves(board, Position[:d, 1])).to match_array([])
      end

      it 'queen can move until blocked' do
        board = fill_board_by_position(parse_positions('c1'), parse_positions('d3'))
        queen = Piece[:white, :queen]
        expected = parse_positions('d2 e1 f1 g1 h1 c2 b3 a4 e2 f3 g4 h5')
        expect(queen.moves(board, Position[:d, 1])).to match_array(expected)
      end

      it 'rook can move until blocked' do
        board = fill_board_by_position(parse_positions('b1'), parse_positions('a7 a8'))
        rook = Piece[:white, :rook]
        expected = parse_positions('a2 a3 a4 a5 a6')
        expect(rook.moves(board, Position[:a, 1])).to match_array(expected)
      end

      it 'white pawn blocked ahead but can capture diagonally' do
        board = fill_board_by_position([], parse_positions('e3 g3 f3'))
        pawn = Piece[:white, :pawn]
        expect(pawn.moves(board, Position[:f, 2])).to match_array([])
      end

      it 'knight can jump over pieces' do
        board = fill_board_by_position(parse_positions('e2 d3'), parse_positions('f3'))
        knight = Piece[:white, :knight]
        expected = parse_positions('c2 g2')
        expect(knight.moves(board, Position[:e, 1])).to match_array(expected)
      end
    end
  end

  describe '#threatened_squares' do
    context 'for pawn' do
      it 'produces correct positions for white pawn at f2' do
        pawn = Piece[:white, :pawn]
        expect(pawn.threatened_squares(empty_board, Position[:f, 2])).to match_array(parse_positions('e3 g3'))
      end
      it 'produces correct positions for white pawn at h2' do
        pawn = Piece[:white, :pawn]
        expect(pawn.threatened_squares(empty_board, Position[:h, 2])).to match_array(parse_positions('g3'))
      end

      it 'produces correct positions for white pawn at a7' do
        pawn = Piece[:white, :pawn]
        expect(pawn.threatened_squares(empty_board, Position[:a, 7])).to match_array(parse_positions('b8'))
      end

      it 'produces correct positions for black pawn at d6' do
        pawn = Piece[:black, :pawn]
        expect(pawn.threatened_squares(empty_board, Position[:d, 6])).to match_array(parse_positions('c5 e5'))
      end
    end

    context 'for other pieces' do
      it 'produces the same positions as move positions for white king ' do
        king = Piece[:white, :king]
        expect(king.threatened_squares(empty_board,
                                       Position[:e, 1])).to match_array(king.moves(empty_board, Position[:e, 1]))
      end

      it 'produces the same positions as move positions for black rook' do
        rook = Piece[:black, :rook]
        expect(rook.threatened_squares(empty_board,
                                       Position[:c, 1])).to match_array(rook.moves(empty_board, Position[:c, 1]))
      end
    end

    context 'with state' do
      let(:state) { double('GameState') }

      before do
        allow(state).to receive(:piece_at).and_return(nil)
      end

      it 'bishop can attack enemy piece but not friendly piece' do
        bishop = Piece[:white, :bishop]
        board = fill_board_by_position(parse_positions('g5'), parse_positions('a3'))
        expected = parse_positions('b2 a3 d2 e3 f4 g5')
        expect(bishop.threatened_squares(board, Position[:c, 1])).to match_array(expected)
      end

      it 'queen attacks include both empty and enemy-occupied squares' do
        queen = Piece[:white, :queen]
        board = fill_board_by_position([], parse_positions('d3 f1'))
        expected = parse_positions('d2 d3 e1 f1 a1 b1 c1 c2 b3 a4 e2 f3 g4 h5')
        expect(queen.threatened_squares(board, Position[:d, 1])).to match_array(expected)
      end

      it 'rook does not attack beyond a blocking piece' do
        rook = Piece[:black, :rook]
        board = fill_board_by_position(parse_positions('a6 a7 a8'), parse_positions('a3'))
        expected = parse_positions('a2 a3 b1 c1 d1 e1 f1 g1 h1') # stops at friendly piece at a3
        expect(rook.threatened_squares(board, Position[:a, 1])).to match_array(expected)
      end

      it 'knight attacks are unaffected by surrounding pieces' do
        knight = Piece[:white, :knight]
        board = fill_board_by_position(parse_positions('d3'), parse_positions('f3'))
        expected = parse_positions('c2 g2 f3 d3') # knight can jump over
        expect(knight.threatened_squares(board, Position[:e, 1])).to match_array(expected)
      end

      it 'pawn attacks empty squares and enemy diagonals only' do
        pawn = Piece[:white, :pawn]
        board = fill_board_by_position([], parse_positions('e3'))
        expect(pawn.threatened_squares(board, Position[:f, 2])).to match_array(parse_positions('e3 g3'))
      end

      it 'pawn attacks friendly diagonals as well (geometry only)' do
        pawn = Piece[:white, :pawn]
        board = fill_board_by_position(parse_positions('e3 g3'), [])
        expect(pawn.threatened_squares(board, Position[:f, 2])).to match_array(parse_positions('e3 g3'))
      end
    end
  end
end
