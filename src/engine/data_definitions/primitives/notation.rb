require_relative '../piece'
require_relative '../square'
require_relative '../components/castling_rights'

# Represents the components of chess notation that are shared by common notation formats.
# Includes utilities for importing and exporting those components.
module CoreNotation
  module_function

  # -- Mappings ---
  PIECE_MAP = {
    king: 'K',
    queen: 'Q',
    rook: 'R',
    bishop: 'B',
    knight: 'N',
    pawn: 'P'
  }.freeze

  CASTLING_MAP = {
    %i[white kingside] => 'K',
    %i[white queenside] => 'Q',
    %i[black kingside] => 'k',
    %i[black queenside] => 'q'
  }.freeze

  FILES_STR = Square::FILES.map(&:to_s).freeze
  RANKS_STR = Square::RANKS.map(&:to_s).freeze

  # Derived mappings
  PIECE_MAP_REVERSE = PIECE_MAP.invert.freeze
  CASTLING_MAP_REVERSE = CASTLING_MAP.invert.freeze

  # --- Pieces ---
  def piece_to_str(piece)
    raise ArgumentError, "Not a valid Piece: #{piece}" unless piece.is_a?(Piece) && piece.valid?

    symbol = PIECE_MAP[piece.type]
    piece.color == :black ? symbol.downcase : symbol
  end

  def str_to_piece(str)
    color = str == str.upcase ? :white : :black
    type = PIECE_MAP_REVERSE.fetch(str.upcase) do
      raise ArgumentError, "Not a valid string: #{str}"
    end

    Piece[color, type]
  end

  # --- Squares ---
  def square_to_str(square)
    raise ArgumentError, "Not a valid Square: #{square}" unless square.is_a?(Square) && square.valid?

    "#{square.file}#{square.rank}"
  end

  def str_to_square(str)
    file, rank = nil
    if str.size == 2
      file, rank = str.chars
      raise ArgumentError, "Not a valid string: #{str}" unless FILES_STR.include?(file) && RANKS_STR.include?(rank)
    elsif FILES_STR.include?(str)
      file = str
    elsif RANKS_STR.include?(str)
      rank = str
    else
      raise ArgumentError, "Not a valid string: #{str}"
    end

    Square[file&.to_sym, rank&.to_i]
  end

  # --- Castling rights ---
  def castling_rights_to_str(rights)
    raise ArgumentError, "Not a CastlingRights: #{rights}" unless rights.is_a?(CastlingRights)

    CASTLING_MAP.reduce('') do |result, (color_side, char)|
      color, side = color_side
      if rights.sides(color).side?(side)
        result + char
      else
        result
      end
    end
  end

  def str_to_castling_rights(str)
    rights = CastlingRights.none
    return rights if str == '-'

    allowed_chars = CASTLING_MAP_REVERSE.keys
    str.chars.each do |char|
      raise ArgumentError, "Not valid string for castling rights: #{str}" unless allowed_chars.include?(char)

      color, side = CASTLING_MAP_REVERSE[char]
      sides = rights.sides(color).with(side => true)
      rights = rights.with(color => sides)

      # Remove all characters up to and including the found character
      # Prevents repeating characters and incorect char order
      allowed_chars = allowed_chars.drop_while { |c| c != char }.drop(1)
    end

    rights
  end
end
