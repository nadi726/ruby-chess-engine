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

# Bypass engine workflow to get to a desired state for testing
def engine_from_state(state, parser: IdentityParser.new, endgame_status: nil, draw_request: nil)
  Engine.send(:__from_raw_state, state, parser: parser, endgame_status: endgame_status, draw_request: draw_request)
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
      it 'returns correct result for white checkmate' do
        #  1. f3 e6 2. g4 Qh4#
        fools_mate = [
          [MovePieceEvent[Position[:f, 2], Position[:f, 3]]],
          [MovePieceEvent[Position[:e, 7], Position[:e, 6]]],
          [MovePieceEvent[Position[:g, 2], Position[:g, 4]]],
          [MovePieceEvent[Position[:d, 8], Position[:h, 4]]]
        ]
        3.times { engine.play_turn(fools_mate[it]) } # right before checkmate
        result = engine.play_turn(fools_mate.last)

        expect(result.game_ended?).to eq(true)
        expect(result.endgame_status).to eq(:white_checkmate)
      end

      it 'returns correct result for black checkmate' do
        scholars_mate = [
          [MovePieceEvent[Position[:e, 2], Position[:e, 4]]],
          [MovePieceEvent[Position[:e, 7], Position[:e, 5]]],
          [MovePieceEvent[Position[:f, 1], Position[:c, 4]]],
          [MovePieceEvent[Position[:a, 7], Position[:a, 6]]],
          [MovePieceEvent[Position[:d, 1], Position[:f, 3]]],
          [MovePieceEvent[Position[:a, 6], Position[:a, 5]]],
          [MovePieceEvent[Position[:f, 3], Position[:f, 7]], RemovePieceEvent[nil, Piece[:black, :pawn]]]
        ]
        6.times { engine.play_turn(scholars_mate[it]) } # right before checkmate
        result = engine.play_turn(scholars_mate.last)

        expect(result.game_ended?).to eq(true)
        expect(result.endgame_status).to eq(:black_checkmate)
      end

      it 'returns correct result for automatic draw' do
        board = fill_board(
          [
            [Piece[:black, :king], Position[:a, 8]],
            [Piece[:white, :king], Position[:c, 1]],
            [Piece[:white, :queen], Position[:c, 3]]

          ]
        )
        gamedata = GameData.start.with(board: board, current_color: :white, castling_rights: CastlingRights.none)
        state = GameState.new(data: gamedata)
        result = engine_from_state(state).play_turn([MovePieceEvent[Position[:c, 3], Position[:c, 7]]])
        expect(result.game_ended?).to eq(true)
        expect(result.endgame_status).to eq(:draw)
      end

      it 'returns an error object for attempting to make a move after the game has ended' do
        board = fill_board(
          [
            [Piece[:white, :king], Position[:e, 1]],
            [Piece[:black, :king], Position[:e, 8]]
          ]
        )
        gamedata = GameData.start.with(board: board, current_color: :white,
                                       castling_rights: CastlingRights.none)
        state = GameState.new(data: gamedata)
        engine = engine_from_state(state, endgame_status: :draw)
        result = engine.play_turn([MovePieceEvent[Position[:e, 1], Position[:e, 2]]])

        expect(result.error).to eq(:game_already_ended)
      end
    end
  end

  describe '#attempt_draw' do
    context 'draw by agreement' do
      it 'ends the game in a draw if both players agree to it on the same turn' do
        listener = spy('listener')
        engine.add_listener(listener)
        engine.attempt_draw(:white)
        engine.attempt_draw(:black)
        expect(listener).to have_received(:on_engine_update).once.with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: :draw)
          )
        )
      end
      it 'ends in draw for requests on the same turn-cycle, but after white moves' do
        listener = spy('listener')
        engine.add_listener(listener)
        engine.attempt_draw(:white)
        engine.play_turn([MovePieceEvent[Position[:b, 2], Position[:b, 4]]])
        engine.attempt_draw(:black)

        expect(listener).to have_received(:on_engine_update).with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: :draw)
          )
        )
      end

      it 'ends in draw for requests on the same turn-cycle, but after black moves' do
        listener = spy('listener')
        engine.add_listener(listener)
        engine.play_turn([MovePieceEvent[Position[:b, 2], Position[:b, 4]]])
        engine.attempt_draw(:black)
        engine.play_turn([MovePieceEvent[Position[:b, 7], Position[:b, 5]]])
        engine.attempt_draw(:white)

        expect(listener).to have_received(:on_engine_update).with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: :draw)
          )
        )
      end

      it "doesn't end in a draw for draw requests by the same player" do
        listener = spy('listener')
        engine.add_listener(listener)
        engine.attempt_draw(:white)
        engine.attempt_draw(:white)
        expect(listener).not_to have_received(:on_engine_update)
      end

      it "doesn't end in a draw for draw requests in different turns" do
        listener = spy('listener')
        engine.add_listener(listener)
        engine.attempt_draw(:black)
        engine.play_turn([MovePieceEvent[Position[:b, 2], Position[:b, 4]]])
        engine.attempt_draw(:white)

        expect(listener).not_to have_received(:on_engine_update).with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: :draw)
          )
        )
      end
    end

    context 'claiming a draw' do
      it 'ends in a draw when draw claim is possible and player claims a draw' do
        data = GameData.start.with(castling_rights: CastlingRights.none, halfmove_clock: 100)
        engine = engine_from_state(GameState.new(data: data))
        result = engine.attempt_draw(:white)
        expect(result.endgame_status).to eq(:draw)
      end
    end
  end
end
