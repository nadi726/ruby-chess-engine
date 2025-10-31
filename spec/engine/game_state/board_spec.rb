# frozen_string_literal: true

require 'game_state/board'
require 'data_definitions/square'
require 'data_definitions/piece'
require 'errors'

RSpec.describe Board do
  let(:pieces) do
    [
      # Rank 1
      Piece[:white, :rook], Piece[:white, :knight], Piece[:white, :bishop], Piece[:white, :queen],
      Piece[:white, :king], Piece[:white, :bishop], Piece[:white, :knight], Piece[:white, :rook],
      # Rank 2
      *Array.new(8) { Piece[:white, :pawn] },
      # Ranks 3-6 (empty)
      *Array.new(32),
      # Rank 7
      *Array.new(8) { Piece[:black, :pawn] },
      # Rank 8
      Piece[:black, :rook], Piece[:black, :knight], Piece[:black, :bishop], Piece[:black, :queen],
      Piece[:black, :king], Piece[:black, :bishop], Piece[:black, :knight], Piece[:black, :rook]
    ]
  end

  subject(:board) { described_class.from_flat_array(pieces) }
  let(:empty_board) { described_class.from_flat_array(Array.new(64)) }

  describe '#get' do
    context 'for valid squares' do
      [
        [Square[:a, 8], Piece[:black, :rook]],
        [Square[:d, 8], Piece[:black, :queen]],
        [Square[:h, 8], Piece[:black, :rook]],
        [Square[:d, 4], nil],
        [Square[:f, 6], nil],
        [Square[:b, 2], Piece[:white, :pawn]],
        [Square[:h, 2], Piece[:white, :pawn]],
        [Square[:a, 1], Piece[:white, :rook]],
        [Square[:e, 1], Piece[:white, :king]],
        [Square[:g, 1], Piece[:white, :knight]]
      ].each do |square, expected_piece|
        it "returns the correct piece for #{square}" do
          expect(board.get(square)).to eq(expected_piece)
        end
      end
    end

    context 'for invalid squares' do
      it 'returns an error for no square given' do
        expect { board.get(5) }.to raise_error(ArgumentError)
      end

      it 'returns an error for square given, but invalid' do
        expect { board.get(Square[:a, 12]) }.to raise_error(InvalidSquareError)
      end
    end
  end

  describe '#insert' do
    let(:piece) { Piece[:black, :queen] }

    context 'for incorrect squares' do
      it 'returns an error for no square given' do
        expect { board.insert(piece, nil) }.to raise_error(ArgumentError)
      end

      it 'returns an error for square given, but invalid' do
        expect { board.insert(piece, Square[:bi, 7]) }.to raise_error(InvalidSquareError)
      end

      it 'returns an error for a valid but occupied square' do
        expect { board.insert(piece, Square[:c, 1]) }.to raise_error(BoardManipulationError)
      end

      it 'raises error when inserting twice at the same square' do
        new_board = empty_board.insert(piece, Square[:e, 4])
        expect { new_board.insert(Piece[:white, :rook], Square[:e, 4]) }.to raise_error(BoardManipulationError)
      end

      it 'rejects an object that does not respond to :type and :color' do
        dummy = Object.new
        expect { empty_board.insert(dummy, Square[:e, 4]) }.to raise_error(ArgumentError)
      end
    end

    context 'for valid piece and square in an empty board' do
      parse_squares('a1 e5 h8').each do |square|
        it "inserts correct piece at #{square}" do
          new_board = empty_board.insert(piece, square)
          expect(new_board.get(square)).to eq(piece)
        end
      end

      it 'does not affect the rest of the board' do
        new_board = empty_board.insert(piece, Square[:f, 4])
        samples = parse_squares('a1 c8 e2 f5')
        values = samples.map { |pos| new_board.get(pos) }
        expect(values).to all(be_nil)
      end

      it 'does not mutate the original board' do
        new_board = empty_board.insert(piece, Square[:e, 4])
        expect(empty_board.get(Square[:e, 4])).to be_nil
        expect(new_board.get(Square[:e, 4])).to eq(piece)
      end
    end

    context 'for valid arguments in a partially occupied board' do
      it 'inserts correct piece at empty square' do
        new_board = board.insert(piece, Square[:d, 3])
        expect(new_board.get(Square[:d, 3])).to eq(piece)
      end

      it 'does not affect surrounding pieces' do
        new_board = board.insert(piece, Square[:c, 6])
        squares = parse_squares('b7 c7 d7 b6 d6 b5 c5 d5')
        old_values = squares.map { |pos| board.get(pos) }
        new_values = squares.map { |pos| new_board.get(pos) }
        expect(old_values).to eq(new_values)
      end

      it 'works correctly for multiple inserts' do
        board2 = board.insert(piece, Square[:c, 3])
        board3 = board2.insert(Piece[:white, :bishop], Square[:h, 4])
        board4 = board3.insert(Piece[:black, :pawn], Square[:g, 6])

        inserted = {
          Square[:c, 3] => piece,
          Square[:h, 4] => Piece[:white, :bishop],
          Square[:g, 6] => Piece[:black, :pawn]
        }

        expect(inserted.all? { |pos, piece| board4.get(pos) == piece }).to be(true)
      end
    end
  end

  describe '#pieces_with_squares' do
    context 'for an empty board' do
      it 'finds nothing for nil type & color' do
        expect(empty_board.pieces_with_squares).to(match_array([]))
      end

      it 'finds nothing for given color' do
        expect(empty_board.pieces_with_squares(color: :black)).to(match_array([]))
      end

      it 'finds nothing for both type and color' do
        expect(empty_board.pieces_with_squares(type: :king, color: :white)).to(match_array([]))
      end
    end

    context 'for partially occupied board' do
      it 'finds all pieces using nil type & color' do
        result = board.pieces_with_squares
        expect(result.map(&:first)).to match_array(pieces.compact)
      end

      it 'finds all black pieces' do
        result = board.pieces_with_squares(color: :black)
        expect(result.map(&:first)).to match_array(pieces[-16..])
      end

      it 'finds all white pieces' do
        result = board.pieces_with_squares(color: :white)
        expect(result.map(&:first)).to match_array(pieces[...16])
      end

      it 'finds all bishops' do
        result = board.pieces_with_squares(type: :bishop)
        expect(result.map(&:first)).to match_array(pieces.select { |p| p&.type == :bishop })
      end

      it 'finds all white bishops' do
        result = board.pieces_with_squares(type: :bishop, color: :white)
        expect(result.map(&:first)).to match_array(pieces.select { |p| p&.type == :bishop && p&.color == :white })
      end

      it 'returns correct piece and square pairs for the kings' do
        result = board.pieces_with_squares(type: :king)
        expect(result).to match_array([
                                        [Piece[:white, :king], Square[:e, 1]],
                                        [Piece[:black, :king], Square[:e, 8]]
                                      ])
      end

      it 'returns correct squares for all white pawns' do
        result = board.pieces_with_squares(type: :pawn, color: :white)
        expected_squares = parse_squares('a2 b2 c2 d2 e2 f2 g2 h2')
        actual_squares = result.map(&:last)
        expect(actual_squares).to match_array(expected_squares)
      end

      it 'returns correct squares for all black pieces' do
        result = board.pieces_with_squares(color: :black)
        expected_squares = parse_squares('a8 b8 c8 d8 e8 f8 g8 h8 a7 b7 c7 d7 e7 f7 g7 h7')
        actual_squares = result.map(&:last)
        expect(actual_squares).to match_array(expected_squares)
      end
    end
  end

  describe '#remove' do
    context 'for incorrect squares' do
      it 'returns an error for no square given' do
        expect { board.remove(nil) }.to raise_error(ArgumentError)
      end

      it 'returns an error for square given, but invalid' do
        expect { board.remove(Square[:c, -1]) }.to raise_error(InvalidSquareError)
      end

      it 'returns an error for a valid but unoccupied square' do
        expect { board.remove(Square[:a, 4]) }.to raise_error(BoardManipulationError)
      end

      it 'raises error when removing twice from the same square' do
        new_board = board.remove(Square[:e, 2])
        expect { new_board.remove(Square[:e, 2]) }.to raise_error(BoardManipulationError)
      end
    end

    context 'for correct squares' do
      context 'removes pieces at occupied squares' do
        parse_squares('a1 b1 c1 e2 g2 b7 c7 f7 a8 d8 h8')
          .each do |square|
          it "removes the piece at #{square}" do
            result_board = board.remove(square)
            expect(result_board.get(square)).to eq(nil)
          end
        end
      end

      it 'removes pieces at occupied squares when used consecutively' do
        squares = [Square[:a, 2], Square[:g, 7], Square[:d, 8]]
        result_board = board.remove(squares[0]).remove(squares[1]).remove(squares[2])
        results = squares.map { |pos| result_board.get(pos) }
        expect(results).to all(be_nil)
      end
    end
  end

  describe '#move' do
    context 'for invalid arguments' do
      it 'returns an error for an unoccupied starting square' do
        expect { board.move(Square[:a, 4], Square[:b, 3]) }.to raise_error(BoardManipulationError)
      end

      it 'returns an error for an occupied target square' do
        expect { board.move(Square[:c, 8], Square[:b, 7]) }.to raise_error(BoardManipulationError)
      end

      it 'returns an error for starting and tartget square being the same square' do
        expect { board.move(Square[:f, 8], Square[:f, 8]) }.to raise_error(BoardManipulationError)
      end

      it 'returns an error for trying to move with the same coordinates twice' do
        squares = [Square[:c, 8], Square[:b, 7]]
        expect { board.move(*squares).move(*squares) }.to raise_error(BoardManipulationError)
      end
    end

    context 'for valid arguments' do
      context 'moves each piece to an unoccupied square' do
        let(:to) { Square[:f, 5] }
        parse_squares('a1 b1 c1 e2 g2 b7 c7 f7 a8 d8 h8')
          .each do |from|
          it "moves the piece at #{from}" do
            result_board = board.move(from, to)
            expect(result_board.get(from)).to eq(nil)
            expect(result_board.get(to)).to eq(board.get(from))
          end
        end
      end

      it 'moves a piece back and forth' do
        squares = parse_squares 'c2 c4'
        result = board.move(*squares).move(*squares.reverse)
        expect(board.pieces_with_squares).to match_array(result.pieces_with_squares)
      end

      it 'can move the same piece across multiple squares' do
        board2 = board.move(Square[:b, 1], Square[:c, 3])
        board3 = board2.move(Square[:c, 3], Square[:e, 4])
        expect(board3.get(Square[:e, 4])).to eq(Piece[:white, :knight])
      end

      it 'moves several pieces to new squares correctly' do
        moves = [parse_squares('a2 a4'), parse_squares('b1 c3'), parse_squares('g7 g5')]
        original_pieces = moves.map { |from, _to| board.get(from) }

        result_board = moves.reduce(board) do |b, (from, to)|
          b.move(from, to)
        end

        moves.zip(original_pieces).each do |(from, to), piece|
          expect(result_board.get(from)).to be_nil
          expect(result_board.get(to)).to eq(piece)
        end
      end
    end
  end

  describe 'cross-method tests' do
    it 'returns all non-nil pieces and their squares matching get' do
      all = board.pieces_with_squares
      all.each do |piece, square|
        expect(board.get(square)).to eq(piece)
      end
    end

    it 'find_pieces returns same pieces as pieces_with_squares.map(&:first)' do
      result = board.find_pieces(type: :pawn, color: :black)
      squares_result = board.pieces_with_squares(type: :pawn, color: :black).map(&:first)
      expect(result).to match_array(squares_result)
    end

    it 'inserting and then removing pieces leads back to empty squares' do
      squares = parse_squares('b4 d5 f6')
      pieces_to_insert = [
        Piece[:white, :knight],
        Piece[:black, :queen],
        Piece[:white, :bishop]
      ]

      board_with_pieces = squares.zip(pieces_to_insert).reduce(empty_board) do |b, (pos, piece)|
        b.insert(piece, pos)
      end

      cleaned_board = squares.reduce(board_with_pieces) { |b, pos| b.remove(pos) }

      squares.each do |pos|
        expect(cleaned_board.get(pos)).to be_nil
      end
    end

    it 'pieces_with_squares and find_pieces return same count' do
      expect(board.pieces_with_squares.count).to eq(board.find_pieces.count)
    end
  end
end
