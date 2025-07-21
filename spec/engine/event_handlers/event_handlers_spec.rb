# frozen_string_literal: true

require 'event_handlers/init'
require 'game_state/game_state'
require 'data_definitions/events'
require 'data_definitions/position'

# NOTE: this is currently outdated.
#       Kept for now for future reference, to migrate the tests.

RSpec.describe EventHandler do
  describe '#handle_events' do
    subject(:handler) { described_class.new(GameState.new) }

    context 'when an incorrect primary event is given' do
      xit 'returns invalid result for invalid event type' do
        result = handler.handle_events(RemovePieceEvent[nil, nil], [])
        expect(result).to be_a_failed_handler_result
      end

      xit 'returns invalid result for invalid pawn move' do
        result = handler.handle_events(MovePieceEvent[Position[:b, 2], Position[:c, 2], nil],
                                       [])
        expect(result).to be_a_failed_handler_result
      end

      xit 'returns invalid result for invalid other piece move' do
        result = handler.handle_events(MovePieceEvent[Position[:h, 1], Position[:h, 3], nil],
                                       [])
        expect(result).to be_a_failed_handler_result
      end
    end

    context 'when an incorrect extra event is given' do
      xit 'returns invalid result with pawn move as primary event' do
        result = handler.handle_events(MovePieceEvent[Position[:b, 2], Position[:b, 3], nil],
                                       [RemovePieceEvent[nil, nil]])
        expect(result).to be_a_failed_handler_result
      end

      xit 'returns invalid result with non-pawn related event as primary event' do
        result = handler.handle_events(MovePieceEvent[Position[:b, 1], Position[:a, 3], nil],
                                       [RemovePieceEvent[nil, nil]])
        expect(result).to be_a_failed_handler_result
      end
    end

    context 'promotion (not implemented yet)' do
      xit 'rejects pawn move to last rank without promotion' do
        # White pawn moves to rank 8 without specifying promotion
        pawn = Piece[:white, :pawn, Position[:g, 7]]
        complex_state.instance_variable_get(:@white_pieces) << pawn

        event = MovePieceEvent[Position[:g, 7], Position[:g, 8], nil]
        result = handler.handle_events(event, [])
        expect(result).to be_a_failed_handler_result
      end
    end
  end
end
