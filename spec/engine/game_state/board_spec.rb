# frozen_string_literal: true

require 'game_state/board'
require 'data_definitions/position'
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
    context 'for valid positions' do
      [
        [Position[:a, 8], Piece[:black, :rook]],
        [Position[:d, 8], Piece[:black, :queen]],
        [Position[:h, 8], Piece[:black, :rook]],
        [Position[:d, 4], nil],
        [Position[:f, 6], nil],
        [Position[:b, 2], Piece[:white, :pawn]],
        [Position[:h, 2], Piece[:white, :pawn]],
        [Position[:a, 1], Piece[:white, :rook]],
        [Position[:e, 1], Piece[:white, :king]],
        [Position[:g, 1], Piece[:white, :knight]]
      ].each do |position, expected_piece|
        it "returns the correct piece for #{position}" do
          expect(board.get(position)).to eq(expected_piece)
        end
      end
    end

    context 'for invalid positions' do
      it 'returns an error for no position given' do
        expect { board.get(5) }.to raise_error(ArgumentError)
      end

      it 'returns an error for position given, but invalid' do
        expect { board.get(Position[:a, 12]) }.to raise_error(InvalidPositionError)
      end
    end
  end

  describe '#insert' do
    let(:piece) { Piece[:black, :queen] }

    context 'for incorrect positions' do
      it 'returns an error for no position given' do
        expect { board.insert(piece, nil) }.to raise_error(ArgumentError)
      end

      it 'returns an error for position given, but invalid' do
        expect { board.insert(piece, Position[:bi, 7]) }.to raise_error(InvalidPositionError)
      end

      it 'returns an error for a valid but occupied position' do
        expect { board.insert(piece, Position[:c, 1]) }.to raise_error(BoardManipulationError)
      end

      it 'raises error when inserting twice at the same position' do
        new_board = empty_board.insert(piece, Position[:e, 4])
        expect { new_board.insert(Piece[:white, :rook], Position[:e, 4]) }.to raise_error(BoardManipulationError)
      end

      it 'rejects an object that does not respond to :type and :color' do
        dummy = Object.new
        expect { empty_board.insert(dummy, Position[:e, 4]) }.to raise_error(ArgumentError)
      end
    end

    context 'for valid piece and position in an empty board' do
      parse_positions('a1 e5 h8').each do |position|
        it "inserts correct piece at #{position}" do
          new_board = empty_board.insert(piece, position)
          expect(new_board.get(position)).to eq(piece)
        end
      end

      it 'does not affect the rest of the board' do
        new_board = empty_board.insert(piece, Position[:f, 4])
        samples = parse_positions('a1 c8 e2 f5')
        values = samples.map { |pos| new_board.get(pos) }
        expect(values).to all(be_nil)
      end

      it 'does not mutate the original board' do
        new_board = empty_board.insert(piece, Position[:e, 4])
        expect(empty_board.get(Position[:e, 4])).to be_nil
        expect(new_board.get(Position[:e, 4])).to eq(piece)
      end
    end

    context 'for valid arguments in a partially occupied board' do
      it 'inserts correct piece at empty square' do
        new_board = board.insert(piece, Position[:d, 3])
        expect(new_board.get(Position[:d, 3])).to eq(piece)
      end

      it 'does not affect surrounding pieces' do
        new_board = board.insert(piece, Position[:c, 6])
        positions = parse_positions('b7 c7 d7 b6 d6 b5 c5 d5')
        old_values = positions.map { |pos| board.get(pos) }
        new_values = positions.map { |pos| new_board.get(pos) }
        expect(old_values).to eq(new_values)
      end

      it 'works correctly for multiple inserts' do
        board2 = board.insert(piece, Position[:c, 3])
        board3 = board2.insert(Piece[:white, :bishop], Position[:h, 4])
        board4 = board3.insert(Piece[:black, :pawn], Position[:g, 6])

        inserted = {
          Position[:c, 3] => piece,
          Position[:h, 4] => Piece[:white, :bishop],
          Position[:g, 6] => Piece[:black, :pawn]
        }

        expect(inserted.all? { |pos, piece| board4.get(pos) == piece }).to be(true)
      end
    end
  end

  describe '#pieces_with_positions' do
    context 'for an empty board' do
      it 'finds nothing for nil type & color' do
        expect(empty_board.pieces_with_positions).to(match_array([]))
      end

      it 'finds nothing for given color' do
        expect(empty_board.pieces_with_positions(color: :black)).to(match_array([]))
      end

      it 'finds nothing for both type and color' do
        expect(empty_board.pieces_with_positions(type: :king, color: :white)).to(match_array([]))
      end
    end

    context 'for partially occupied board' do
      it 'finds all pieces using nil type & color' do
        result = board.pieces_with_positions
        expect(result.map(&:first)).to match_array(pieces.compact)
      end

      it 'finds all black pieces' do
        result = board.pieces_with_positions(color: :black)
        expect(result.map(&:first)).to match_array(pieces[-16..])
      end

      it 'finds all white pieces' do
        result = board.pieces_with_positions(color: :white)
        expect(result.map(&:first)).to match_array(pieces[...16])
      end

      it 'finds all bishops' do
        result = board.pieces_with_positions(type: :bishop)
        expect(result.map(&:first)).to match_array(pieces.select { |p| p&.type == :bishop })
      end

      it 'finds all white bishops' do
        result = board.pieces_with_positions(type: :bishop, color: :white)
        expect(result.map(&:first)).to match_array(pieces.select { |p| p&.type == :bishop && p&.color == :white })
      end

      it 'returns correct piece and position pairs for the kings' do
        result = board.pieces_with_positions(type: :king)
        expect(result).to match_array([
                                        [Piece[:white, :king], Position[:e, 1]],
                                        [Piece[:black, :king], Position[:e, 8]]
                                      ])
      end

      it 'returns correct positions for all white pawns' do
        result = board.pieces_with_positions(type: :pawn, color: :white)
        expected_positions = parse_positions('a2 b2 c2 d2 e2 f2 g2 h2')
        actual_positions = result.map(&:last)
        expect(actual_positions).to match_array(expected_positions)
      end

      it 'returns correct positions for all black pieces' do
        result = board.pieces_with_positions(color: :black)
        expected_positions = parse_positions('a8 b8 c8 d8 e8 f8 g8 h8 a7 b7 c7 d7 e7 f7 g7 h7')
        actual_positions = result.map(&:last)
        expect(actual_positions).to match_array(expected_positions)
      end
    end
  end

  describe '#remove' do
    context 'for incorrect positions' do
      it 'returns an error for no position given' do
        expect { board.remove(nil) }.to raise_error(ArgumentError)
      end

      it 'returns an error for position given, but invalid' do
        expect { board.remove(Position[:c, -1]) }.to raise_error(InvalidPositionError)
      end

      it 'returns an error for a valid but unoccupied position' do
        expect { board.remove(Position[:a, 4]) }.to raise_error(BoardManipulationError)
      end

      it 'raises error when removing twice from the same position' do
        new_board = board.remove(Position[:e, 2])
        expect { new_board.remove(Position[:e, 2]) }.to raise_error(BoardManipulationError)
      end
    end

    context 'for correct positions' do
      context 'removes pieces at occupied positions' do
        parse_positions('a1 b1 c1 e2 g2 b7 c7 f7 a8 d8 h8')
          .each do |position|
          it "removes the piece at #{position}" do
            result_board = board.remove(position)
            expect(result_board.get(position)).to eq(nil)
          end
        end
      end

      it 'removes pieces at occupied positions when used consecutively' do
        positions = [Position[:a, 2], Position[:g, 7], Position[:d, 8]]
        result_board = board.remove(positions[0]).remove(positions[1]).remove(positions[2])
        results = positions.map { |pos| result_board.get(pos) }
        expect(results).to all(be_nil)
      end
    end
  end

  describe '#move' do
    context 'for invalid arguments' do
      it 'returns an error for an unoccupied starting position' do
        expect { board.move(Position[:a, 4], Position[:b, 3]) }.to raise_error(BoardManipulationError)
      end

      it 'returns an error for an occupied target position' do
        expect { board.move(Position[:c, 8], Position[:b, 7]) }.to raise_error(BoardManipulationError)
      end

      it 'returns an error for starting and tartget position being the same position' do
        expect { board.move(Position[:f, 8], Position[:f, 8]) }.to raise_error(BoardManipulationError)
      end

      it 'returns an error for trying to move with the same coordinates twice' do
        positions = [Position[:c, 8], Position[:b, 7]]
        expect { board.move(*positions).move(*positions) }.to raise_error(BoardManipulationError)
      end
    end

    context 'for valid arguments' do
      context 'moves each piece to an unoccupied position' do
        let(:to) { Position[:f, 5] }
        parse_positions('a1 b1 c1 e2 g2 b7 c7 f7 a8 d8 h8')
          .each do |from|
          it "moves the piece at #{from}" do
            result_board = board.move(from, to)
            expect(result_board.get(from)).to eq(nil)
            expect(result_board.get(to)).to eq(board.get(from))
          end
        end
      end

      it 'moves a piece back and forth' do
        positions = parse_positions 'c2 c4'
        result = board.move(*positions).move(*positions.reverse)
        expect(board.pieces_with_positions).to match_array(result.pieces_with_positions)
      end

      it 'can move the same piece across multiple positions' do
        board2 = board.move(Position[:b, 1], Position[:c, 3])
        board3 = board2.move(Position[:c, 3], Position[:e, 4])
        expect(board3.get(Position[:e, 4])).to eq(Piece[:white, :knight])
      end

      it 'moves several pieces to new positions correctly' do
        moves = [parse_positions('a2 a4'), parse_positions('b1 c3'), parse_positions('g7 g5')]
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
    it 'returns all non-nil pieces and their positions matching get' do
      all = board.pieces_with_positions
      all.each do |piece, position|
        expect(board.get(position)).to eq(piece)
      end
    end

    it 'find_pieces returns same pieces as pieces_with_positions.map(&:first)' do
      result = board.find_pieces(type: :pawn, color: :black)
      positions_result = board.pieces_with_positions(type: :pawn, color: :black).map(&:first)
      expect(result).to match_array(positions_result)
    end

    it 'inserting and then removing pieces leads back to empty positions' do
      positions = parse_positions('b4 d5 f6')
      pieces_to_insert = [
        Piece[:white, :knight],
        Piece[:black, :queen],
        Piece[:white, :bishop]
      ]

      board_with_pieces = positions.zip(pieces_to_insert).reduce(empty_board) do |b, (pos, piece)|
        b.insert(piece, pos)
      end

      cleaned_board = positions.reduce(board_with_pieces) { |b, pos| b.remove(pos) }

      positions.each do |pos|
        expect(cleaned_board.get(pos)).to be_nil
      end
    end

    it 'pieces_with_positions and find_pieces return same count' do
      expect(board.pieces_with_positions.count).to eq(board.find_pieces.count)
    end
  end
end
