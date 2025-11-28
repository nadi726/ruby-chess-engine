# frozen_string_literal: true

require_relative 'format_matcher'

RSpec.describe Formatters::ERANLongFormatter do
  subject(:formatter) { described_class }

  context 'regular moves' do
    it 'formats quiet pawn move' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:e, 2], Square[:e, 4]]
      expect(formatter).to format(event).and_return('Pawn e2-e4')
    end

    it 'formats quiet piece move' do
      event = MovePieceEvent[Piece[:black, :knight], Square[:b, 1], Square[:c, 3]]
      expect(formatter).to format(event).and_return('Knight b1-c3')
    end

    it 'formats normal capture (non-pawn)' do
      event = MovePieceEvent[Piece[:white, :rook], Square[:a, 1], Square[:a, 8]].capture(Square[:a, 8],
                                                                                         Piece[:black, :pawn])
      expect(formatter).to format(event).and_return('Rook a1xa8')
    end

    it 'formats pawn capture' do
      event = MovePieceEvent[Piece[:black, :pawn], Square[:f, 5], Square[:e, 6]].capture(Square[:e, 6],
                                                                                         Piece[:white, :pawn])
      expect(formatter).to format(event).and_return('Pawn f5xe6')
    end

    it 'formats promotion' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:g, 7], Square[:g, 8]].promote(:queen)
      expect(formatter).to format(event).and_return('Pawn g7-g8 ->Queen')
    end
  end

  context 'special moves' do
    it 'formats en passant' do
      event = EnPassantEvent[:white, Square[:e, 5], Square[:d, 6]]
      expect(formatter).to format(event).and_return('en-passant')
    end

    it 'formats kingside castling' do
      event = CastlingEvent[:black, :kingside]
      expect(formatter).to format(event).and_return('castling-kingside')
    end

    it 'formats queenside castling' do
      event = CastlingEvent[:white, :queenside]
      expect(formatter).to format(event).and_return('castling-queenside')
    end
  end

  context 'invalid events' do
    it 'does not format non-event objects' do
      expect(formatter).not_to format(nil)
      expect(formatter).not_to format(Object.new)
    end

    it 'does not format events with missing piece' do
      event = MovePieceEvent[nil, Square[:e, 2], Square[:e, 4]]
      expect(formatter).not_to format(event)
    end

    it 'does not format events with missing from_square' do
      event = MovePieceEvent[Piece[:white, :pawn], nil, Square[:e, 4]]
      expect(formatter).not_to format(event)
    end

    it 'does not format events with missing to_square' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:e, 2], nil]
      expect(formatter).not_to format(event)
    end

    it 'does not format events with invalid piece type' do
      event = MovePieceEvent[Piece[:white, :dragon], Square[:e, 2], Square[:e, 4]]
      expect(formatter).not_to format(event)
    end

    it 'does not format events with invalid square' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:z, 9], Square[:e, 4]]
      expect(formatter).not_to format(event)
      event2 = MovePieceEvent[Piece[:white, :pawn], Square[:e, 2], Square[:h, 9]]
      expect(formatter).not_to format(event2)
    end

    it 'does not format events with invalid promotion piece' do
      event = MovePieceEvent[Piece[:white, :pawn], Square[:g, 7], Square[:g, 8]].promote(:dragon)
      expect(formatter).not_to format(event)
    end
  end
end
