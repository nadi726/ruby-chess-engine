# frozen_string_literal: true

# PersistentArray provides an immutable, tree-based fixed-size array.
# It's designed specifically for use by the Board class to support immutable updates,
# allowing efficient structural sharing of board state in GameState.
#
# Not intended as a general-purpose data structure outside of this context.

module PersistentArrayConfig
  SIZE = 64
  BRANCHING_FACTOR = 8
end

class PersistentArray
  include PersistentArrayConfig
  include Enumerable

  # The public interface
  def self.from_values(values)
    raise ArgumentError, "Expected exactly #{SIZE} elements, got #{values.size}" unless values.size == SIZE

    new(InternalNode.from_values(values))
  end

  # Do not use directly - intended to be private
  def initialize(root)
    @root = root
  end

  def get(index)
    raise IndexError, "Index #{index} out of bounds" unless (0...SIZE).cover?(index)

    @root.get(index, SIZE)
  end

  def set(index, new_value)
    raise IndexError, "Index #{index} out of bounds" unless (0...SIZE).cover?(index)

    PersistentArray.new(@root.set(index, new_value, SIZE))
  end

  def each(&block)
    @root.each(&block)
  end
end

# A PersistentArray node that holds references to other nodes
class InternalNode
  include PersistentArrayConfig

  def self.from_values(values)
    chunk_size = values.size / BRANCHING_FACTOR
    node_class = chunk_size == BRANCHING_FACTOR ? LeafNode : InternalNode
    branches = Array.new(BRANCHING_FACTOR) do |i|
      node_class.from_values(values[chunk_size * i, chunk_size])
    end

    InternalNode.new(branches)
  end

  def initialize(branches)
    @branches = branches.freeze
  end

  def get(index, chunk_size)
    new_chunk_size = chunk_size / BRANCHING_FACTOR
    branch_index, inner_index = index.divmod(new_chunk_size)
    @branches[branch_index].get(inner_index, new_chunk_size)
  end

  def set(index, value, chunk_size)
    new_chunk_size = chunk_size / BRANCHING_FACTOR
    branch_index, inner_index = index.divmod(new_chunk_size)
    new_branches = @branches.dup
    new_branches[branch_index] = new_branches[branch_index].set(inner_index, value, new_chunk_size)
    InternalNode.new(new_branches)
  end

  def each(&block)
    @branches.each { |branch| branch.each(&block) }
  end
end

# A PersistentArray node that holds values
class LeafNode
  include PersistentArrayConfig

  # For compatibility with InternalNode
  def self.from_values(values)
    LeafNode.new(values)
  end

  def initialize(values)
    @values = values.freeze
  end

  def get(index, _)
    @values[index]
  end

  def set(index, value, _)
    new_values = @values.dup
    new_values[index] = value
    LeafNode.new(new_values)
  end

  def each(&block)
    @values.each(&block)
  end
end
