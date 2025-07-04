# frozen_string_literal: true

require 'game_state/board'
require 'data_definitions/position'

# As Piece is not yet compatible with Board, since it is mutable with position
PieceStub = Struct.new(:type, :color)

RSpec.describe Board do
  let(:pieces) do
    [
      # Rank 1
      PieceStub.new(:rook, :white), PieceStub.new(:knight, :white), PieceStub.new(:bishop, :white), PieceStub.new(:queen, :white),
      PieceStub.new(:king, :white), PieceStub.new(:bishop, :white), PieceStub.new(:knight, :white), PieceStub.new(:rook, :white),
      # Rank 2
      *Array.new(8) { PieceStub.new(:pawn, :white) },
      # Ranks 3-6 (empty)
      *Array.new(32),
      # Rank 7
      *Array.new(8) { PieceStub.new(:pawn, :black) },
      # Rank 8
      PieceStub.new(:rook, :black), PieceStub.new(:knight, :black), PieceStub.new(:bishop, :black), PieceStub.new(:queen, :black),
      PieceStub.new(:king, :black), PieceStub.new(:bishop, :black), PieceStub.new(:knight, :black), PieceStub.new(:rook, :black)
    ]
  end

  subject(:board) { described_class.from_flat_array(pieces) }
  let(:empty_board) { described_class.from_flat_array(Array.new(64)) }

  describe '#get' do
    context 'for valid positions' do
      [
        [Position.new(:a, 8), PieceStub.new(:rook, :black)],
        [Position.new(:d, 8), PieceStub.new(:queen, :black)],
        [Position.new(:h, 8), PieceStub.new(:rook, :black)],
        [Position.new(:d, 4), nil],
        [Position.new(:f, 6), nil],
        [Position.new(:b, 2), PieceStub.new(:pawn, :white)],
        [Position.new(:h, 2), PieceStub.new(:pawn, :white)],
        [Position.new(:a, 1), PieceStub.new(:rook, :white)],
        [Position.new(:e, 1), PieceStub.new(:king, :white)],
        [Position.new(:g, 1), PieceStub.new(:knight, :white)]
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
        expect { board.get(Position.new(:a, 12)) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#insert' do
    let(:piece) { PieceStub.new(:queen, :black) }

    context 'for incorrect positions' do
      it 'returns an error for no position given' do
        expect { board.insert(piece, nil) }.to raise_error(ArgumentError)
      end

      it 'returns an error for position given, but invalid' do
        expect { board.insert(piece, Position.new(:bi, 7)) }.to raise_error(ArgumentError)
      end

      it 'returns an error for a valid but occupied position' do
        expect { board.insert(piece, Position.new(:c, 1)) }.to raise_error(ArgumentError)
      end

      it 'raises error when inserting twice at the same position' do
        new_board = empty_board.insert(piece, Position.new(:e, 4))
        expect { new_board.insert(PieceStub.new(:rook, :white), Position.new(:e, 4)) }.to raise_error(ArgumentError)
      end

      it 'rejects an object that does not respond to :type and :color' do
        dummy = Object.new
        expect { empty_board.insert(dummy, Position.new(:e, 4)) }.to raise_error(ArgumentError)
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
        new_board = empty_board.insert(piece, Position.new(:f, 4))
        samples = parse_positions('a1 c8 e2 f5')
        values = samples.map { |pos| new_board.get(pos) }
        expect(values).to all(be_nil)
      end

      it 'does not mutate the original board' do
        new_board = empty_board.insert(piece, Position.new(:e, 4))
        expect(empty_board.get(Position.new(:e, 4))).to be_nil
        expect(new_board.get(Position.new(:e, 4))).to eq(piece)
      end
    end

    context 'for valid arguments in a partially occupied board' do
      it 'inserts correct piece at empty square' do
        new_board = board.insert(piece, Position.new(:d, 3))
        expect(new_board.get(Position.new(:d, 3))).to eq(piece)
      end

      it 'does not affect surrounding pieces' do
        new_board = board.insert(piece, Position.new(:c, 6))
        positions = parse_positions('b7 c7 d7 b6 d6 b5 c5 d5')
        old_values = positions.map { |pos| board.get(pos) }
        new_values = positions.map { |pos| new_board.get(pos) }
        expect(old_values).to eq(new_values)
      end

      it 'works correctly for multiple inserts' do
        board2 = board.insert(piece, Position.new(:c, 3))
        board3 = board2.insert(PieceStub.new(:bishop, :white), Position.new(:h, 4))
        board4 = board3.insert(PieceStub.new(:pawn, :black), Position.new(:g, 6))

        inserted = {
          Position.new(:c, 3) => piece,
          Position.new(:h, 4) => PieceStub.new(:bishop, :white),
          Position.new(:g, 6) => PieceStub.new(:pawn, :black)
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
                                        [PieceStub.new(:king, :white), Position.new(:e, 1)],
                                        [PieceStub.new(:king, :black), Position.new(:e, 8)]
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
        expect { board.remove(Position.new(:c, -1)) }.to raise_error(ArgumentError)
      end

      it 'returns an error for a valid but unoccupied position' do
        expect { board.remove(Position.new(:a, 4)) }.to raise_error(ArgumentError)
      end

      it 'raises error when removing twice from the same position' do
        new_board = board.remove(Position.new(:e, 2))
        expect { new_board.remove(Position.new(:e, 2)) }.to raise_error(ArgumentError)
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
        positions = [Position.new(:a, 2), Position.new(:g, 7), Position.new(:d, 8)]
        result_board = board.remove(positions[0]).remove(positions[1]).remove(positions[2])
        results = positions.map { |pos| result_board.get(pos) }
        expect(results).to all(be_nil)
      end
    end
  end

  describe '#move' do
    context 'for invalid arguments' do
      it 'returns an error for an unoccupied starting position' do
        expect { board.move(Position.new(:a, 4), Position.new(:b, 3)) }.to raise_error(ArgumentError)
      end

      it 'returns an error for an occupied target position' do
        expect { board.move(Position.new(:c, 8), Position.new(:b, 7)) }.to raise_error(ArgumentError)
      end

      it 'returns an error for starting and tartget position being the same position' do
        expect { board.move(Position.new(:f, 8), Position.new(:f, 8)) }.to raise_error(ArgumentError)
      end

      it 'returns an error for trying to move with the same coordinates twice' do
        positions = [Position.new(:c, 8), Position.new(:b, 7)]
        expect { board.move(*positions).move(*positions) }.to raise_error(ArgumentError)
      end
    end

    context 'for valid arguments' do
      context 'moves each piece to an unoccupied position' do
        let(:to) { Position.new(:f, 5) }
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
        board2 = board.move(Position.new(:b, 1), Position.new(:c, 3))
        board3 = board2.move(Position.new(:c, 3), Position.new(:e, 4))
        expect(board3.get(Position.new(:e, 4))).to eq(PieceStub.new(:knight, :white))
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
        PieceStub.new(:knight, :white),
        PieceStub.new(:queen, :black),
        PieceStub.new(:bishop, :white)
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
