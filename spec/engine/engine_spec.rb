# frozen_string_literal: true

require 'engine'
require 'parsers/identity_parser'
require 'game_state/game_state'
require 'data_definitions/events'
require 'data_definitions/position'

# Checks that the TurnResult’s board matches the expected board.
# Testing just the board requires much less setup and thus allows for much simpler testing
RSpec::Matchers.define :have_board do |board|
  match do |turn_result|
    turn_result&.game_query&.board == board
  end
end

RSpec.describe Engine do
  subject(:engine) { described_class.new(IdentityParser.new) }
  describe '#play_turn' do
    describe 'general game progression' do
      it 'processes a valid move correctly' do
        result = engine.play_turn([MovePieceEvent[Position[:d, 2], Position[:d, 4]]])
        result_board = Board.start.move(Position[:d, 2], Position[:d, 4])
        expect(result.events).to eq([MovePieceEvent[Position[:d, 2], Position[:d, 4], Piece[:white, :pawn]]])
        expect(result).to have_board(result_board)
      end

      # TODO: maybe smoke test with a couple event sequences

      it 'notifies listeners after a valid move' do
        listener = spy('listener')
        engine.add_listener(listener)
        result = engine.play_turn([MovePieceEvent[Position[:g, 1], Position[:g, 3]]])
        expect(listener).to have_received(:on_engine_update).with(result)
      end

      it 'notifies listeners after an invalid move' do
        listener = spy('listener')
        engine.add_listener(listener)
        result = engine.play_turn([MovePieceEvent[Position[:g, 1], Position[:g, 5]]])
        expect(listener).to have_received(:on_engine_update).with(result)
      end

      it 'returns the correct error for invalid notation' do
        result = engine.play_turn(50) # Even IdentityParser has minimal validation
        expect(result.error).to eq(:invalid_notation)
      end
      it 'returns the correct error for invalid move' do
        result = engine.play_turn([MovePieceEvent[Position[:c, 2], Position[:f, 5]]])
        expect(result.error).to eq(:invalid_event_sequence)
      end

      it 'does not advance the engine after a failure' do
        expect { engine.play_turn([MovePieceEvent[Position[:h, 5], Piece[:black, :queen]]]) }.not_to(change { engine })
      end
    end

    describe 'endgame' do
      # TODO
    end
  end

  describe '#attempt_draw' do
    # TODO
  end
end
