# frozen_string_literal: true

require 'game_state/game_state'

module StartState
  def start_state
    @start_state ||= GameState.start
  end

  def start_position
    start_state.query.position
  end

  def start_board
    start_position.board
  end

  def start_query
    start_state.query
  end
end
