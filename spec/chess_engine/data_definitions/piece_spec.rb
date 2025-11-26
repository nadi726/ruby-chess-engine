# frozen_string_literal: true

describe Piece do
  let(:empty_board) { Board.empty }

  describe '#moves' do
    context 'for king' do
      subject(:king) { Piece[:white, :king] }
      it 'produces correct squares from starting position' do
        expect(king.moves(empty_board, Square[:e, 1])).to match_array(parse_squares('d1 d2 e2 f1 f2'))
      end

      it 'produces correct squares from a central position' do
        expect(king.moves(empty_board, Square[:d, 4])).to match_array(parse_squares('c3 c4 c5 d3 d5 e3 e4 e5'))
      end

      it 'produces correct squares from a corner' do
        expect(king.moves(empty_board, Square[:a, 1])).to match_array(parse_squares('a2 b1 b2'))
      end
    end

    context 'for queen' do
      subject(:queen) { Piece[:black, :queen] }

      it 'produces correct squares from starting position' do
        expect(
          queen.moves(empty_board, Square[:d, 8])
        ).to match_array(parse_squares('a8 b8 c8 e8 f8 g8 h8 d7 d6 d5 d4 d3 d2 d1 c7 b6 a5 e7 f6 g5 h4'))
      end

      it 'produces correct squares from a central position' do
        expect(
          queen.moves(empty_board, Square[:f, 5])
        ).to match_array(parse_squares('a5 b5 c5 d5 e5 g5 h5 f1 f2 f3 f4 f6 f7 f8 h7 g6 e4 d3 c2 b1 c8 d7 e6 g4 h3'))
      end

      it 'produces correct squares from a corner' do
        expect(
          queen.moves(empty_board, Square[:a, 8])
        ).to match_array(parse_squares('a1 a2 a3 a4 a5 a6 a7 b8 c8 d8 e8 f8 g8 h8 b7 c6 d5 e4 f3 g2 h1'))
      end
    end

    context 'for rook' do
      subject(:rook) { Piece[:white, :rook] }

      it 'produces correct squares from a central position' do
        squares = parse_squares('c1 c2 c4 c5 c6 c7 c8 a3 b3 d3 e3 f3 g3 h3')
        expect(rook.moves(empty_board, Square[:c, 3])).to match_array(squares)
      end

      it 'produces correct squares from a corner' do
        squares = parse_squares('h2 h3 h4 h5 h6 h7 h8 a1 b1 c1 d1 e1 f1 g1')
        expect(rook.moves(empty_board, Square[:h, 1])).to match_array(squares)
      end
    end

    context 'for bishop' do
      subject(:bishop) { Piece[:black, :bishop] }

      it 'produces correct squares from c1' do
        expect(bishop.moves(empty_board, Square[:c, 1])).to match_array(parse_squares('b2 a3 d2 e3 f4 g5 h6'))
      end

      it 'produces correct squares from center' do
        expected_squares = parse_squares('a1 b2 c3 e5 f6 g7 h8 a7 b6 c5 e3 f2 g1')
        expect(bishop.moves(empty_board, Square[:d, 4])).to match_array(expected_squares)
      end

      it 'produces correct squares for corner' do
        expected_squares = parse_squares('b7 c6 d5 e4 f3 g2 h1')
        expect(bishop.moves(empty_board, Square[:a, 8])).to match_array(expected_squares)
      end
    end

    context 'for knight' do
      subject(:knight) { Piece[:white, :knight] }

      it 'produces correct squares from a central position' do
        expect(knight.moves(empty_board,
                            Square[:e, 3])).to match_array(parse_squares('c2 c4 d1 f1 g2 g4 f5 d5'))
      end

      it 'produces correct squares from a corner' do
        expect(knight.moves(empty_board, Square[:h, 1])).to match_array(parse_squares('g3 f2'))
      end
    end

    context 'for black pawn' do
      subject(:black_pawn) { Piece[:black, :pawn] }

      it 'can move both 1 and 2 steps from starting position' do
        expect(black_pawn.moves(empty_board, Square[:d, 7])).to match_array(parse_squares('d6 d5'))
      end

      it 'can move only 1 step from non-starting position' do
        expect(black_pawn.moves(empty_board, Square[:d, 6])).to match_array(parse_squares('d5'))
      end

      it 'has no moves when on the promotion rank' do
        expect(black_pawn.moves(empty_board, Square[:d, 1])).to match_array([])
      end
    end

    context 'for white pawn' do
      subject(:white_pawn) { Piece[:white, :pawn] }

      it 'can move both 1 and 2 steps from starting position' do
        expect(white_pawn.moves(empty_board, Square[:f, 2])).to match_array(parse_squares('f3 f4'))
      end

      it 'can move only 1 step from non-starting position' do
        expect(white_pawn.moves(empty_board, Square[:f, 6])).to match_array(parse_squares('f7'))
      end
    end

    context 'with non-empty board' do
      context 'with no blocking pieces' do
        it 'pawn can move both 1 and 2 steps from starting position' do
          black_pawn = Piece[:black, :pawn]
          expect(black_pawn.moves(start_board,
                                  Square.new(:d,
                                             7))).to match_array(black_pawn.moves(empty_board,
                                                                                  Square[:d, 7]))
        end
      end

      it 'white queen surrounded by friendly pieces' do
        board = fill_board_by_square(parse_squares('c1 c2 d2 e1 e2'), [])
        queen = Piece[:white, :queen]
        expect(queen.moves(board, Square[:d, 1])).to match_array([])
      end

      it 'queen can move until blocked' do
        board = fill_board_by_square(parse_squares('c1'), parse_squares('d3'))
        queen = Piece[:white, :queen]
        expected = parse_squares('d2 e1 f1 g1 h1 c2 b3 a4 e2 f3 g4 h5')
        expect(queen.moves(board, Square[:d, 1])).to match_array(expected)
      end

      it 'rook can move until blocked' do
        board = fill_board_by_square(parse_squares('b1'), parse_squares('a7 a8'))
        rook = Piece[:white, :rook]
        expected = parse_squares('a2 a3 a4 a5 a6')
        expect(rook.moves(board, Square[:a, 1])).to match_array(expected)
      end

      it 'white pawn blocked ahead but can capture diagonally' do
        board = fill_board_by_square([], parse_squares('e3 g3 f3'))
        pawn = Piece[:white, :pawn]
        expect(pawn.moves(board, Square[:f, 2])).to match_array([])
      end

      it 'knight can jump over pieces' do
        board = fill_board_by_square(parse_squares('e2 d3'), parse_squares('f3'))
        knight = Piece[:white, :knight]
        expected = parse_squares('c2 g2')
        expect(knight.moves(board, Square[:e, 1])).to match_array(expected)
      end
    end
  end

  describe '#threatened_squares' do
    context 'for pawn' do
      it 'produces correct squares for white pawn at f2' do
        pawn = Piece[:white, :pawn]
        expect(pawn.threatened_squares(empty_board, Square[:f, 2])).to match_array(parse_squares('e3 g3'))
      end
      it 'produces correct squares for white pawn at h2' do
        pawn = Piece[:white, :pawn]
        expect(pawn.threatened_squares(empty_board, Square[:h, 2])).to match_array(parse_squares('g3'))
      end

      it 'produces correct squares for white pawn at a7' do
        pawn = Piece[:white, :pawn]
        expect(pawn.threatened_squares(empty_board, Square[:a, 7])).to match_array(parse_squares('b8'))
      end

      it 'produces correct squares for black pawn at d6' do
        pawn = Piece[:black, :pawn]
        expect(pawn.threatened_squares(empty_board, Square[:d, 6])).to match_array(parse_squares('c5 e5'))
      end
    end

    context 'for other pieces' do
      it 'produces the same squares as move squares for white king ' do
        king = Piece[:white, :king]
        expect(king.threatened_squares(empty_board,
                                       Square[:e, 1])).to match_array(king.moves(empty_board, Square[:e, 1]))
      end

      it 'produces the same squares as move squares for black rook' do
        rook = Piece[:black, :rook]
        expect(rook.threatened_squares(empty_board,
                                       Square[:c, 1])).to match_array(rook.moves(empty_board, Square[:c, 1]))
      end
    end

    context 'with non-empty board' do
      it 'bishop can attack enemy piece but not friendly piece' do
        bishop = Piece[:white, :bishop]
        board = fill_board_by_square(parse_squares('g5'), parse_squares('a3'))
        expected = parse_squares('b2 a3 d2 e3 f4 g5')
        expect(bishop.threatened_squares(board, Square[:c, 1])).to match_array(expected)
      end

      it 'queen attacks include both empty and enemy-occupied squares' do
        queen = Piece[:white, :queen]
        board = fill_board_by_square([], parse_squares('d3 f1'))
        expected = parse_squares('d2 d3 e1 f1 a1 b1 c1 c2 b3 a4 e2 f3 g4 h5')
        expect(queen.threatened_squares(board, Square[:d, 1])).to match_array(expected)
      end

      it 'rook does not attack beyond a blocking piece' do
        rook = Piece[:black, :rook]
        board = fill_board_by_square(parse_squares('a6 a7 a8'), parse_squares('a3'))
        expected = parse_squares('a2 a3 b1 c1 d1 e1 f1 g1 h1') # stops at friendly piece at a3
        expect(rook.threatened_squares(board, Square[:a, 1])).to match_array(expected)
      end

      it 'knight attacks are unaffected by surrounding pieces' do
        knight = Piece[:white, :knight]
        board = fill_board_by_square(parse_squares('d3'), parse_squares('f3'))
        expected = parse_squares('c2 g2 f3 d3') # knight can jump over
        expect(knight.threatened_squares(board, Square[:e, 1])).to match_array(expected)
      end

      it 'pawn attacks empty squares and enemy diagonals only' do
        pawn = Piece[:white, :pawn]
        board = fill_board_by_square([], parse_squares('e3'))
        expect(pawn.threatened_squares(board, Square[:f, 2])).to match_array(parse_squares('e3 g3'))
      end

      it 'pawn attacks friendly diagonals as well (geometry only)' do
        pawn = Piece[:white, :pawn]
        board = fill_board_by_square(parse_squares('e3 g3'), [])
        expect(pawn.threatened_squares(board, Square[:f, 2])).to match_array(parse_squares('e3 g3'))
      end
    end
  end
end
