# frozen_string_literal: true

require 'data_definitions/primitives/notation'

RSpec.describe CoreNotation do
  describe 'Pieces' do
    it 'converts a valid Piece to string notation' do
      piece = Piece[:white, :king]
      expect(CoreNotation.piece_to_str(piece)).to eq('K')
    end

    it 'raises an error for invalid Piece objects' do
      invalid_piece = Piece[:white, :invalid_type]
      expect { CoreNotation.piece_to_str(invalid_piece) }
        .to raise_error(ArgumentError)
    end

    it 'converts valid notation to a Piece' do
      expect(CoreNotation.str_to_piece('b')).to eq(Piece[:black, :bishop])
    end

    it 'raises an error for invalid notation' do
      expect { CoreNotation.str_to_piece('X') }
        .to raise_error(ArgumentError)
    end
  end

  describe 'Squares' do
    it 'converts a valid Square to string notation' do
      square = Square[:e, 4]
      expect(CoreNotation.square_to_str(square)).to eq('e4')
    end

    it 'raises an error for invalid Square objects' do
      invalid_square = Square[:invalid_file, 9]
      expect { CoreNotation.square_to_str(invalid_square) }
        .to raise_error(ArgumentError)
    end

    it 'converts a valid string to a Square object' do
      expect(CoreNotation.str_to_square('c2')).to eq(Square[:c, 2])
    end

    it 'raises an error for invalid square strings' do
      expect { CoreNotation.str_to_square('z9') }
        .to raise_error(ArgumentError)
    end
  end

  describe 'Castling rights' do
    it 'converts valid CastlingRights to string notation' do
      rights = CastlingRights[CastlingSides.start, CastlingSides[false, true]]
      expect(CoreNotation.castling_rights_to_str(rights)).to eq('KQq')
    end

    it 'raises an error for invalid CastlingRights objects' do
      invalid_rights = Object.new
      expect { CoreNotation.castling_rights_to_str(invalid_rights) }
        .to raise_error(ArgumentError)
    end

    it 'converts valid string to CastlingRights' do
      rights = CastlingRights[CastlingSides.start, CastlingSides.none]
      expect(CoreNotation.str_to_castling_rights('KQ')).to eq(rights)
    end

    it 'raises an error for invalid castling rights string' do
      expect { CoreNotation.str_to_castling_rights('X') }
        .to raise_error(ArgumentError)
    end
  end
end
