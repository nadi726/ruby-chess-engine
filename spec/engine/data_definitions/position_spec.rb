require 'data_definitions/position'

describe Position do
  describe '.from_fen' do
    it 'parses the standard starting position' do
      fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
      pos = Position.from_fen(fen)
      expect(pos.to_fen).to eq(fen)
    end

    it 'parses a midgame position' do
      fen = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3'
      pos = Position.from_fen(fen)
      expect(pos.to_fen).to eq(fen)
    end

    it 'raises an error for invalid FEN (too few fields)' do
      expect { Position.from_fen('invalid fen string') }.to raise_error(ArgumentError)
    end

    it 'raises an error for invalid color' do
      fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1'
      expect { Position.from_fen(fen) }.to raise_error(ArgumentError)
    end
  end

  describe '#to_fen' do
    it 'outputs the correct FEN for the starting position' do
      expect(Position.start.to_fen).to eq('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
    end

    it 'outputs the correct FEN for a position with no castling rights and en passant' do
      pos = Position[
        board: Board.start,
        current_color: :black,
        en_passant_target: Square[:e, 3],
        castling_rights: CastlingRights.none,
        halfmove_clock: 5,
        fullmove_number: 10
      ]
      expect(pos.to_fen).to eq('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b - e3 5 10')
    end

    it 'outputs the correct FEN for a position with only black castling rights' do
      pos = Position[
        board: Board.start,
        current_color: :black,
        en_passant_target: nil,
        castling_rights: CastlingRights[
          CastlingSides.none,
          CastlingSides.start
        ],
        halfmove_clock: 0,
        fullmove_number: 1
      ]
      expect(pos.to_fen).to eq('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b kq - 0 1')
    end

    it 'raises an error if called on an invalid position' do
      pos = Position[
        board: :INVALID,
        current_color: :black,
        en_passant_target: nil,
        castling_rights: nil,
        halfmove_clock: 0,
        fullmove_number: 1
      ]
      expect { pos.to_fen }.to raise_error
    end
  end
end
