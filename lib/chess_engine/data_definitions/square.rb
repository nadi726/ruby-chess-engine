# frozen_string_literal: true

require_relative '../errors'

module ChessEngine
  # Represents chessboard squares, each with a rank and a file,
  # and provides methods for validation, conversion, and manipulation of squares within the chess engine.
  #
  # An invalid `Square` (e.g., off the board) can be created but must not be used, as this will cause an error.
  # Ensure validity with `#valid?` before usage.
  class Square
    FILES = (:a..:h).to_a.freeze
    RANKS = (1..8).to_a.freeze

    attr_reader :file, :rank

    def initialize(file, rank)
      @file = file
      @rank = rank
    end

    def self.from_index(row, col)
      return new(nil, nil) unless (0..7).cover?(row) && (0..7).cover?(col)

      new(FILES[col], RANKS[row])
    end

    # Produces a standard array representation of [row, column]
    def to_a
      return InvalidSquareError unless valid?

      [@rank - 1, FILES.index(@file)]
    end

    def offset(file_delta, rank_delta)
      row, col = to_a
      row += rank_delta
      col += file_delta
      Square.from_index(row, col)
    end

    # Returns the distance between self and the given Square object.
    # The result is of the format [file_distance, rank_distance].
    # For example, the distance from b2 to d2 is [2, 0].
    def distance(other)
      raise InvalidSquareError unless valid? && other&.valid?

      file_distance = (FILES.index(file) - FILES.index(other.file)).abs
      rank_distance = (rank - other.rank).abs
      [file_distance, rank_distance]
    end

    # Returns true if self is partially included in the other square.
    # For this method, self doesn't have to be a full, valid square.
    # It can have any of the following: specific rank and file,
    # specific file (nil rank), specific rank (nil file), or both being nil.
    # `other` is a complete, valid square.
    def matches?(other)
      file_matches = file.nil? || file == other.file
      rank_matches = rank.nil? || rank == other.rank

      file_matches && rank_matches
    end

    def valid?
      FILES.include?(file) && RANKS.include?(rank)
    end

    def to_s
      return "#<Square (INVALID) file=#{file.inspect}, rank=#{rank.inspect}>" unless valid?

      "#{file}#{rank}"
    end

    # For cleaner test messages
    def inspect
      to_s
    end

    def ==(other)
      other.is_a?(Square) && file == other.file && rank == other.rank
    end

    def eql?(other)
      self == other
    end

    def hash
      [file, rank].hash
    end

    # For `Square[file, rank]` syntax.
    # Makes it clearer that this is a value object, similar to Data
    def self.[](file, rank)
      new(file, rank)
    end
  end
end
