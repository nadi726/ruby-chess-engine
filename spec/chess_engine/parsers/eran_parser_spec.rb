# frozen_string_literal: true

RSpec::Matchers.define :parse do |notation_str|
  chain :and_return do |expected_result|
    @expected_result = expected_result
  end

  match do |parser|
    @actual_result = parser.call(notation_str)

    if @expected_result
      values_match?(@actual_result, @expected_result)
    else
      !@actual_result.nil?
    end
  end

  failure_message do |parser|
    if @expected_result
      "expected #{parser} to parse '#{notation_str}' into:\n  " \
        "#{@expected_result.inspect}\n" \
        "but got:\n  " \
        "#{@actual_result.inspect}"
    else
      "expected #{parser} to parse '#{notation_str}', but it returned nil"
    end
  end

  failure_message_when_negated do |parser_class|
    "expected #{parser_class} not to parse '#{notation_str}', but it returned:\n  #{@actual_result.inspect}"
  end
end

RSpec.describe Parsers::ERANParser do
  subject(:parser) { described_class }

  context 'regular moves' do
    it 'parses quiet pawn move' do
      event = MovePieceEvent[Piece[nil, :pawn], Square[:e, 2], Square[:e, 4]]
      expect(parser).to parse('Pawn e2-e4').and_return(event)
      expect(parser).to parse('P e2-e4').and_return(event)
    end

    it 'parses quiet piece move' do
      event = MovePieceEvent[Piece[nil, :knight], Square[:b, 1], Square[:c, 3]]
      expect(parser).to parse('Knight b1-c3').and_return(event)
      expect(parser).to parse('N b1-c3').and_return(event)
    end

    it 'parses normal capture (non-pawn)' do
      event = MovePieceEvent[Piece[nil, :rook], Square[:a, 1], Square[:a, 8]].capture
      expect(parser).to parse('Rook a1xa8').and_return(event)
      expect(parser).to parse('R a1xa8').and_return(event)
    end

    it 'parses pawn capture' do
      event = MovePieceEvent[Piece[nil, :pawn], Square[:f, 5], Square[:e, 6]].capture
      expect(parser).to parse('Pawn f5xe6').and_return(event)
      expect(parser).to parse('P f5xe6').and_return(event)
    end

    it 'parses promotion' do
      event = MovePieceEvent[Piece[nil, :pawn], Square[:g, 7], Square[:g, 8]].promote(:queen)
      expect(parser).to parse('Pawn g7-g8 ->Queen').and_return(event)
      expect(parser).to parse('p g7-g8 >q').and_return(event)
    end

    it 'parses mixed case moves' do
      expect(parser).to parse('KNIGHT b1-c3')
      expect(parser).to parse('N b1-C3')
      expect(parser).to parse('RooK B1Xa8')
      expect(parser).to parse('Pawn g7-g8 ->QUEEN')
    end

    it 'parses moves with arbitrary space between fields' do
      expect(parser).to parse('  Pawn   e2-e4  ')
      expect(parser).to parse("P\t e2-e4")
      expect(parser).to parse('  Knight   b1-c3 ')
      expect(parser).to parse("N\tb1-c3")
      expect(parser).to parse('  P   g7-g8   >Q   ')
      expect(parser).to parse('  ep   ')
      expect(parser).to parse('   castling-kingside   ')
    end
  end

  context 'special moves' do
    it 'parses valid en passant' do
      event = EnPassantEvent[nil, nil, nil]
      expect(parser).to parse('ep').and_return(event)
      expect(parser).to parse('en-passant').and_return(event)
      expect(parser).to parse('EP').and_return(event)
      expect(parser).to parse('EN-PASSANT').and_return(event)
    end

    it 'parses valid kingside castling' do
      event = CastlingEvent[nil, :kingside]
      expect(parser).to parse('ck').and_return(event)
      expect(parser).to parse('castling-kingside').and_return(event)
      expect(parser).to parse('CK').and_return(event)
      expect(parser).to parse('CASTLING-KINGSIDE').and_return(event)
    end

    it 'parses valid queenside castling' do
      event = CastlingEvent[nil, :queenside]
      expect(parser).to parse('cq').and_return(event)
      expect(parser).to parse('castling-queenside').and_return(event)
      expect(parser).to parse('CQ').and_return(event)
      expect(parser).to parse('CASTLING-QUEENSIDE').and_return(event)
    end
  end

  context 'invalid moves' do
    it "doesn't parse missing piece type" do
      expect(parser).not_to parse('e2-e4')
    end

    it "doesn't parse missing destination" do
      expect(parser).not_to parse('Pawn e2-')
    end

    it "doesn't parse invalid square" do
      expect(parser).not_to parse('Pawn z9-e4')
      expect(parser).not_to parse('N a9-b3')
      expect(parser).not_to parse('P h0-h9')
    end

    it "doesn't parse invalid promotion" do
      expect(parser).not_to parse('Pawn g7-g8 ->Dragon')
      expect(parser).not_to parse('P g7-g8 >X')
    end

    it "doesn't parse extra characters in regular moves" do
      expect(parser).not_to parse('Pawn e2-e4!')
      expect(parser).not_to parse('N b1-c3#')
      expect(parser).not_to parse('R a1xa8??')
    end

    it "doesn't parse extra characters in special moves" do
      expect(parser).not_to parse('en-passant.')
      expect(parser).not_to parse('ep!')
      expect(parser).not_to parse('ck!')
      expect(parser).not_to parse('castling-kingside.')
      expect(parser).not_to parse('cq!')
      expect(parser).not_to parse('castling-queenside.')
    end

    it "doesn't parse completely invalid notation" do
      expect(parser).not_to parse('The king is dead, long live the king!')
      expect(parser).not_to parse('random text')
      expect(parser).not_to parse('12345')
      expect(parser).not_to parse('Pawn e2-e4 e5-e6')
      expect(parser).not_to parse('P e2-e4 P e7-e5')
    end
  end
end
