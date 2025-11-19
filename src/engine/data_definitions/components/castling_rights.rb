# frozen_string_literal: true

# Represents complete castling rights of both color for a certain position
CastlingRights = Data.define(
  :white, :black
) do
  def self.start
    new(CastlingSides.start, CastlingSides.start)
  end

  def self.none
    new(CastlingSides.none, CastlingSides.none)
  end

  def sides(color)
    case color
    when :white then white
    when :black then black
    else
      raise ArgumentError, "Invalid color: #{color.inspect}"
    end
  end
end

# Tracks whether each side still retains castling rights.
# Rights may be lost due to moving the king or rook, or other game events.
CastlingSides = Data.define(:kingside, :queenside) do
  def self.start
    new(true, true)
  end

  def self.none
    new(false, false)
  end

  def side?(side)
    case side
    when :kingside then kingside
    when :queenside then queenside
    else
      raise ArgumentError, "Invalid castling side: #{side.inspect}"
    end
  end
end
