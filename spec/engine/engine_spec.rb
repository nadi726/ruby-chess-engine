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

# Helper for tests only — bypasses Engine’s public constructor to inject arbitrary game states.
def engine_from_state(state, parser: IdentityParser.new, endgame_status: nil, offered_draw: nil)
  Engine.send(:__from_raw_state, state, parser: parser, endgame_status: endgame_status, offered_draw: offered_draw)
end

RSpec.describe Engine do
  let(:listener) { spy('listener') }
  subject(:engine) do
    eng = described_class.new(IdentityParser.new)
    eng.add_listener(listener)
    eng
  end

  describe '#play_turn' do
    describe 'general game progression' do
      it 'processes a valid move correctly' do
        result = engine.play_turn([MovePieceEvent[Position[:d, 2], Position[:d, 4]]])
        result_board = Board.start.move(Position[:d, 2], Position[:d, 4])
        expect(result.events).to eq([MovePieceEvent[Position[:d, 2], Position[:d, 4], Piece[:white, :pawn]]])
        expect(result).to have_board(result_board)
      end

      it 'handles a basic sequence of moves without error' do
        moves = [
          [MovePieceEvent[Position[:e, 2], Position[:e, 4]]],
          [MovePieceEvent[Position[:e, 7], Position[:e, 5]]],
          [MovePieceEvent[Position[:g, 1], Position[:f, 3]]],
          [MovePieceEvent[Position[:b, 8], Position[:c, 6]]]
        ]
        moves.each do |move|
          result = engine.play_turn(move)
          expect(result).to be_success
        end
      end

      it 'notifies listeners after a valid move' do
        result = engine.play_turn([MovePieceEvent[Position[:g, 1], Position[:g, 3]]])
        expect(listener).to have_received(:on_engine_update).with(result)
      end

      it 'notifies listeners after an invalid move' do
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

        expect(result).to be_success
        expect(result.game_ended?).to eq(true)
        expect(result.endgame_status).to eq(GameOutcome[:black, :checkmate])
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
        expect(result.endgame_status).to eq(GameOutcome[:white, :checkmate])
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
        expect(result.endgame_status).to eq(GameOutcome[:draw, :stalemate])
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
        engine = engine_from_state(state, endgame_status: GameOutcome[:draw, :insufficient_material])
        result = engine.play_turn([MovePieceEvent[Position[:e, 1], Position[:e, 2]]])

        expect(result).to be_failure
        expect(result.error).to eq(:game_already_ended)
      end
    end
  end

  describe 'draw methods' do
    context 'draw by agreement' do
      it 'ends the game in a draw if both players agree to it on the same turn' do
        engine.offer_draw
        engine.play_turn([MovePieceEvent[Position[:b, 2], Position[:b, 4]]])
        engine.accept_draw
        expect(listener).to have_received(:on_engine_update).once.with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: GameOutcome[:draw, :agreement])
          )
        )
      end

      it 'clears offered draw after the offering side moves' do
        engine.offer_draw
        engine.play_turn([MovePieceEvent[Position[:e, 2], Position[:e, 4]]])
        engine.play_turn([MovePieceEvent[Position[:b, 7], Position[:b, 5]]])
        engine.accept_draw
        expect(listener).not_to have_received(:on_engine_update).with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: GameOutcome[:draw, :agreement])
          )
        )
      end

      it 'ends in draw for requests on the same turn-cycle, but after black moves' do
        engine.play_turn([MovePieceEvent[Position[:b, 2], Position[:b, 4]]])
        engine.offer_draw
        engine.play_turn([MovePieceEvent[Position[:b, 7], Position[:b, 5]]])
        engine.accept_draw

        expect(listener).to have_received(:on_engine_update).with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: GameOutcome[:draw, :agreement])
          )
        )
      end

      it "doesn't end in a draw when accepting a draw comes before offering it" do
        engine.accept_draw
        engine.play_turn([MovePieceEvent[Position[:b, 2], Position[:b, 4]]])
        engine.offer_draw
        expect(listener).not_to have_received(:on_engine_update).with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: GameOutcome[:draw, :agreement])
          )
        )
      end

      it "doesn't end in a draw for draw offer and acceptance by the same player" do
        engine.offer_draw
        engine.accept_draw
        expect(listener).not_to have_received(:on_engine_update)
      end

      it "offering a draw again on the same turn doesn't affect outcome" do
        engine.offer_draw
        engine.offer_draw
        expect(listener).not_to have_received(:on_engine_update)
      end

      it "doesn't change the outcome of a game that has already ended" do
        fools_mate = [
          [MovePieceEvent[Position[:f, 2], Position[:f, 3]]],
          [MovePieceEvent[Position[:e, 7], Position[:e, 6]]],
          [MovePieceEvent[Position[:g, 2], Position[:g, 4]]],
          [MovePieceEvent[Position[:d, 8], Position[:h, 4]]]
        ]
        3.times { engine.play_turn(fools_mate[it]) }
        engine.offer_draw
        engine.play_turn(fools_mate.last) # checkmate
        engine.accept_draw
        expect(listener).not_to have_received(:on_engine_update).with(
          an_instance_of(TurnResult).and(
            have_attributes(endgame_status: GameOutcome[:draw, :agreement])
          )
        )
      end
    end

    context '#claim_draw' do
      it 'ends in a draw when draw claim is possible' do
        data = GameData.start.with(castling_rights: CastlingRights.none, halfmove_clock: 100)
        engine = engine_from_state(GameState.new(data: data))
        result = engine.claim_draw
        expect(result.endgame_status).to eq(GameOutcome[:draw, :fifty_move])
      end

      it "doesn't end in a draw when player is not eligible" do
        result = engine.claim_draw
        expect(result).to eq(nil)
      end

      it "doesn't change the outcome of a game that has already ended" do
        board = fill_board(
          [
            [Piece[:black, :king], Position[:a, 8]],
            [Piece[:white, :king], Position[:c, 1]],
            [Piece[:white, :queen], Position[:c, 7]]
          ]
        )
        gamedata = GameData.start.with(board: board, current_color: :white, castling_rights: CastlingRights.none,
                                       halfmove_clock: 120)
        engine = engine_from_state(GameState.new(data: gamedata), endgame_status: GameOutcome[:draw, :stalemate])
        engine.add_listener(listener)
        engine.claim_draw
        expect(listener).not_to have_received(:on_engine_update)
      end
    end
  end

  describe '#resign' do
    it 'ends the game when player resigns' do
      engine.resign
      expect(listener).to have_received(:on_engine_update).with(
        an_instance_of(TurnResult).and(
          have_attributes(endgame_status: GameOutcome[:black, :resignation])
        )
      )
    end

    it "doesn't change the outcome of a game that has already ended" do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:a, 8]],
          [Piece[:white, :king], Position[:c, 1]],
          [Piece[:white, :queen], Position[:c, 7]]
        ]
      )
      gamedata = GameData.start.with(board: board, current_color: :white, castling_rights: CastlingRights.none)
      engine = engine_from_state(GameState.new(data: gamedata), endgame_status: GameOutcome[:draw, :stalemate])
      engine.add_listener(listener)
      engine.resign
      expect(listener).not_to have_received(:on_engine_update)
    end
  end
end
