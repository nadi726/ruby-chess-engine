# frozen_string_literal: true

require_relative 'format_matcher'

RSpec.describe Formatters::ERANShortFormatter do
  subject(:formatter) { described_class }

  context 'regular moves' do
    it 'formats quiet pawn move' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:a, 2], Square[:a, 4]]
      expect(formatter).to format(event).and_return('P a2-a4')
    end

    it 'formats piece move' do
      event = MovePieceEvent[Piece[:black, :bishop], Square[:c, 8], Square[:f, 5]]
      expect(formatter).to format(event).and_return('B c8-f5')
    end

    it 'formats capture' do
      event = MovePieceEvent[Piece[:white, :queen], Square[:d, 1], Square[:h, 5]].capture(Square[:h, 5],
                                                                                          Piece[:black, :pawn])
      expect(formatter).to format(event).and_return('Q d1xh5')
    end

    it 'formats promotion' do
      event = MovePieceEvent[Piece[:black, :pawn], Square[:b, 2], Square[:b, 1]].promote(:rook)
      expect(formatter).to format(event).and_return('P b2-b1 >R')
    end
  end

  context 'special moves' do
    it 'formats en passant' do
      event = EnPassantEvent[:black, Square[:c, 5], Square[:d, 6]]
      expect(formatter).to format(event).and_return('ep')
    end

    it 'formats castling' do
      expect(formatter).to format(CastlingEvent[:black, :kingside]).and_return('ck')
      expect(formatter).to format(CastlingEvent[:white, :queenside]).and_return('cq')
    end
  end

  context 'invalid events' do
    it 'does not format nil or random object' do
      expect(formatter).not_to format(nil)
      expect(formatter).not_to format(Object.new)
    end

    it 'does not format event with invalid piece type' do
      event = MovePieceEvent[Piece[:white, :unicorn], Square[:e, 2], Square[:e, 4]]
      expect(formatter).not_to format(event)
    end

    it 'does not format event with invalid square' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:z, 9], Square[:e, 4]]
      expect(formatter).not_to format(event)
    end
  end
end
