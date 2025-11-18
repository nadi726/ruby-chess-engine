# frozen_string_literal: true

require 'immutable'
require_relative 'position'

# Encapsulates all of the game's history, from a certain point up to a current point.
#
# Includes:
# - `start_position`: a `Position` object representing the position from which the history started.
# - `moves` - an `Enumerable` of events that happened up until the current point.
# - `position_signatures` - a hash of position signatures, that counts how much times each one occured up to this point.
GameHistory = Data.define(:start_position, :moves, :position_signatures) do
  def initialize(moves:, position_signatures: Immutable::Hash[], start_position: Position.start)
    moves = Immutable.from moves
    position_signatures = Immutable.from position_signatures
    super
  end

  def self.start = new(Position.start, Immutable::List[], Immutable::Hash[])
end
