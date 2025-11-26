# frozen_string_literal: true

require_relative 'state'
require_relative 'query'
require_relative 'history'

module ChessEngine
  # Contains the core abstractions for representing and manipulating chess game state.
  # The main entry point is `State`, which models the entire game at a given moment.
  # Other components (`Query`, `History`) are dependencies of `State` but can be used standalone if needed.
  #
  # For details and usage, see the documentation in `State`.
  module Game
  end
end
