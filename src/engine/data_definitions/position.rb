# frozen_string_literal: true

# The Position class is used to encapsulate the file (column) and rank (row) of a square,
# and provides methods for validation, conversion, and manipulation of positions within the chess engine.
# A Position may be invalid (e.g. off the board).
# It is the responsibility of the engine to check validity using the valid? method when necessary.
class Position
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
    [@rank - 1, FILES.index(@file)]
  end

  def offset(file_delta, rank_delta)
    row, col = to_a
    row += rank_delta
    col += file_delta
    Position.from_index(row, col)
  end

  # Returns the distance between self and the given Position object.
  # The result is of the format [file_distance, rank_distance]
  # For exmaple, the distance from b2 to d2 is [2, 0]
  def distance(other)
    file_distance = (FILES.index(file) - FILES.index(other.file)).abs
    rank_distance = (rank - other.rank).abs
    [file_distance, rank_distance]
  end

  def valid?
    FILES.include?(file) && RANKS.include?(rank)
  end

  def to_s
    "#{file}#{rank}"
  end

  # For cleaner test messages
  def inspect
    to_s
  end

  def ==(other)
    other.is_a?(Position) && file == other.file && rank == other.rank
  end

  def eql?(other)
    self == other
  end

  def hash
    [file, rank].hash
  end

  # For Position[file, rank] syntax.
  # Makes it clearer that this is a value object, similar to Data
  def self.[](file, rank)
    new(file, rank)
  end
end
