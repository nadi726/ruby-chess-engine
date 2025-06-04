# frozen_string_literal: true

require 'data_definitions/position'

describe Position do
  let(:a1) { Position.new(:a, 1) }
  let(:h8) { Position.new(:h, 8) }

  describe '#from_index' do
    it 'maps [0, 0] to a1' do
      result = Position.from_index(0, 0)
      expect(result).to eq(a1)
    end

    it 'maps [7, 7] to h8' do
      result = Position.from_index(7, 7)
      expect(result).to eq(h8)
    end

    it 'maps [3, 4] to e4' do
      result = Position.from_index(3, 4)
      expect(result).to eq(Position.new(:e, 4))
    end

    it 'returns an invalid position when out of bounds' do
      result = Position.from_index(8, 0)
      expect(result.valid?).to be false
    end
  end

  describe '#to_a' do
    it 'converts a1 to [0, 0]' do
      result = a1.to_a
      expect(result).to eq([0, 0])
    end

    it 'converts h8 to [7, 7]' do
      result = h8.to_a
      expect(result).to eq([7, 7])
    end

    it 'converts b6 to [5, 1]' do
      b6 = Position.new(:b, 6)
      result = b6.to_a
      expect(result).to eq([5, 1])
    end
  end

  describe '#offset' do
    context 'for a1' do
      it 'offsets with (1, 0) to b1' do
        result = a1.offset(1, 0)
        expect(result).to eq(Position.new(:b, 1))
      end

      it 'offsets with (0, 2) to a3' do
        result = a1.offset(0, 2)
        expect(result).to eq(Position.new(:a, 3))
      end

      it 'offsets with (7, 7) to h8' do
        result = a1.offset(7, 7)
        expect(result).to eq(h8)
      end
    end

    context 'for h8' do
      it 'offsets with (-3, -2) to e6' do
        result = h8.offset(-3, -2)
        expect(result).to eq(Position.new(:e, 6))
      end

      it 'does not mutate the object' do
        h8.offset(-1, -1)
        expect(h8).to eq(Position.new(:h, 8))
      end
    end

    context 'for d4' do
      subject(:d4) { Position.new(:d, 4) }

      it 'offsets with (1, 4) to e8' do
        result = d4.offset(1, 4)
        expect(result).to eq(Position.new(:e, 8))
      end

      it 'offsets with (-3, -3) to a1' do
        result = d4.offset(-3, -3)
        expect(result).to eq(Position.new(:a, 1))
      end

      it 'offsets with (-2, 3) to b7' do
        result = d4.offset(-2, 3)
        expect(result).to eq(Position.new(:b, 7))
      end
    end
  end

  describe '#distance' do
    context 'no distance' do
      it 'returns correct result for a1' do
        result = a1.distance a1
        expect(result).to eq([0, 0])
      end

      it 'returns correct result for h8' do
        result = h8.distance h8
        expect(result).to eq([0, 0])
      end
    end

    context 'horizontal-only' do
      b2 = Position.new(:b, 2)
      d2 = Position.new(:d, 2)
      h2 = Position.new(:h, 2)

      it 'returns [2, 0] for b2 to d2' do
        result = b2.distance d2
        expect(result).to eq([2, 0])
      end

      it 'returns [2, 0] for d2 to b2' do
        result = d2.distance b2
        expect(result).to eq([2, 0])
      end

      it 'returns [6, 0] for b2 to h2' do
        result = b2.distance h2
        expect(result).to eq([6, 0])
      end
    end

    context 'vertical-only' do
      c1 = Position.new(:c, 1)
      c5 = Position.new(:c, 5)

      it 'returns [0, 4] for c1 to c5' do
        result = c5.distance c1
        expect(result).to eq([0, 4])
      end
    end

    context 'both horizontal and diagonal' do
      it 'returns [3, 3] for a1 to d4' do
        d4 = Position.new(:d, 4)
        result = a1.distance d4
        expect(result).to eq([3, 3])
      end

      it 'returns [7, 7] for a1 to h8' do
        result = a1.distance h8
        expect(result).to eq([7, 7])
      end

      it 'returns [2, 5] for b3 to d8' do
        b3 = Position.new(:b, 3)
        d8 = Position.new(:d, 8)
        result = b3.distance d8
        expect(result).to eq([2, 5])
      end
    end
  end

  describe '#valid?' do
    context 'valid positions' do
      it 'returns true for a1' do
        expect(a1).to be_valid
      end

      it 'returns true for h8' do
        expect(h8).to be_valid
      end

      it 'returns true for c7' do
        c7 = Position.new(:c, 7)
        expect(c7).to be_valid
      end
    end

    context 'invalid positions' do
      it 'returns false for non-string file' do
        pos = Position.new(4, 3)
        expect(pos).not_to be_valid
      end

      it 'returns false for non-letter file' do
        pos = Position.new('$', 3)
        expect(pos).not_to be_valid
      end

      it 'returns false for too-high letter file' do
        pos = Position.new(:i, 3)
        expect(pos).not_to be_valid
      end

      it 'returns false for rank 0' do
        pos = Position.new(:f, 0)
        expect(pos).not_to be_valid
      end

      it 'returns false for negative rank' do
        pos = Position.new(:f, -3)
        expect(pos).not_to be_valid
      end

      it 'returns false for rank > 8' do
        pos = Position.new(:f, 9)
        expect(pos).not_to be_valid
      end
    end
  end

  describe '#to_s' do
    it 'returns "a1" for a1' do
      expect(a1.to_s).to eq('a1')
    end

    it 'returns "h8" for h8' do
      expect(h8.to_s).to eq('h8')
    end
  end
end
