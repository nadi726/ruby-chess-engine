# frozen_string_literal: true

require 'engine'
require 'parsers/identity_parser'

# Checks that the `GameUpdate`’s board matches the expected board.
RSpec::Matchers.define :have_board do |board|
  match do |game_update|
    game_update&.game_query&.board == board
  end
end

# Helper for tests only — bypasses `Engine`’s public constructor to inject arbitrary game states.
def engine_from_state(state, offered_draw: nil)
  engine = Engine.new(IdentityParser)
  engine.send(:load_game_state, state, offered_draw: offered_draw)
  engine
end

RSpec.describe Engine do
  let(:listener) { spy('listener') }
  subject(:engine) { described_class.new(IdentityParser) }
  subject(:ended_game_engine) do
    board = fill_board(
      [
        [Piece[:white, :king], Square[:e, 1]],
        [Piece[:black, :king], Square[:e, 8]]
      ]
    )
    position = Position.start.with(board: board, current_color: :white,
                                   castling_rights: CastlingRights.none)
    state = GameState.load(position)
    engine_from_state(state)
  end

  before do
    ended_game_engine.add_listener(listener)
    engine.add_listener(listener)
    engine.new_game
  end

  describe '#play_turn' do
    describe 'general game progression' do
      it 'processes a valid move correctly' do
        result = engine.play_turn(MovePieceEvent[nil, Square[:d, 2], Square[:d, 4]])
        result_board = Board.start.move(Square[:d, 2], Square[:d, 4])
        expect(result.event).to eq(MovePieceEvent[Piece[:white, :pawn], Square[:d, 2], Square[:d, 4]])
        expect(result).to have_board(result_board)
      end

      it 'handles a basic sequence of moves without error' do
        moves = [
          MovePieceEvent[nil, Square[:e, 2], Square[:e, 4]],
          MovePieceEvent[nil, Square[:e, 7], Square[:e, 5]],
          MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[:f, 3]],
          MovePieceEvent[Piece[:black, :knight], Square[:b, 8], Square[:c, 6]]
        ]
        moves.each do |move|
          result = engine.play_turn(move)
          expect(result).to be_success
        end
      end

      it 'notifies listeners after a valid move' do
        result = engine.play_turn(MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[:g, 3]])
        expect(listener).to have_received(:on_game_update).with(result)
      end

      it 'notifies listeners after an invalid move' do
        result = engine.play_turn(MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[:g, 5]])
        expect(listener).to have_received(:on_game_update).with(result)
      end

      it 'returns the correct error for invalid notation' do
        result = engine.play_turn(50) # Even `IdentityParser` has minimal validation
        expect(result.error).to eq(:invalid_notation)
      end
      it 'returns the correct error for invalid move' do
        result = engine.play_turn(MovePieceEvent[nil, Square[:c, 2], Square[:f, 5]])
        expect(result.error).to eq(:invalid_event)
      end

      it 'does not advance the engine after a failure' do
        expect do
          engine.play_turn(MovePieceEvent[Piece[:black, :queen], nil, Square[:h, 5]])
        end.not_to(change { engine })
      end
    end

    describe 'endgame' do
      it 'returns correct result for white checkmate' do
        #  1. f3 e6 2. g4 Qh4#
        fools_mate = [
          MovePieceEvent[nil, Square[:f, 2], Square[:f, 3]],
          MovePieceEvent[nil, Square[:e, 7], Square[:e, 6]],
          MovePieceEvent[nil, Square[:g, 2], Square[:g, 4]],
          MovePieceEvent[Piece[:black, :queen], Square[:d, 8], Square[:h, 4]]
        ]
        3.times { engine.play_turn(fools_mate[it]) } # right before checkmate
        result = engine.play_turn(fools_mate.last)
        expect(result).to be_success
        expect(result.endgame_status).to eq(GameOutcome[:black, :checkmate])
        expect(result.game_ended?).to eq(true)
      end

      it 'returns correct result for black checkmate' do
        scholars_mate = [
          MovePieceEvent[nil, Square[:e, 2], Square[:e, 4]],
          MovePieceEvent[nil, Square[:e, 7], Square[:e, 5]],
          MovePieceEvent[Piece[nil, :bishop], Square[:f, 1], Square[:c, 4]],
          MovePieceEvent[nil, Square[:a, 7], Square[:a, 6]],
          MovePieceEvent[Piece[nil, :queen], Square[:d, 1], Square[:f, 3]],
          MovePieceEvent[nil, Square[:a, 6], Square[:a, 5]],
          MovePieceEvent[Piece[nil, :queen], Square[:f, 3], Square[:f, 7]].capture(nil, Piece[:black, :pawn])
        ]
        6.times { engine.play_turn(scholars_mate[it]) } # right before checkmate
        result = engine.play_turn(scholars_mate.last)

        expect(result.game_ended?).to eq(true)
        expect(result.endgame_status).to eq(GameOutcome[:white, :checkmate])
      end

      it 'returns correct result for automatic draw' do
        board = fill_board(
          [
            [Piece[:black, :king], Square[:a, 8]],
            [Piece[:white, :king], Square[:c, 1]],
            [Piece[:white, :queen], Square[:c, 3]]
          ]
        )
        position = Position.start.with(board: board, current_color: :white, castling_rights: CastlingRights.none)
        state = GameState.load(position)
        result = engine_from_state(state).play_turn(MovePieceEvent[Piece[nil, :queen], Square[:c, 3], Square[:c, 7]])
        expect(result.game_ended?).to eq(true)
        expect(result.endgame_status).to eq(GameOutcome[:draw, :stalemate])
      end

      it 'returns an error object for attempting to make a move after the game has ended' do
        result = ended_game_engine.play_turn(MovePieceEvent[Piece[:white, :king], Square[:e, 1], Square[:e, 2]])

        expect(result).to be_failure
        expect(result.error).to eq(:game_already_ended)
      end
    end
  end

  describe 'draw methods' do
    context 'draw by agreement' do
      it 'ends the game in a draw if both players agree to it on the same turn (white offers)' do
        engine.offer_draw
        engine.play_turn(MovePieceEvent[nil, Square[:b, 2], Square[:b, 4]])
        engine.accept_draw
        expect(listener).to have_received(:on_game_update).once.with(
          an_instance_of(GameUpdate).and(
            have_attributes(endgame_status: GameOutcome[:draw, :agreement])
          )
        )
      end

      it 'ends the game in a draw if both players agree to it on the same turn (black offers)' do
        engine.play_turn(MovePieceEvent[nil, Square[:b, 2], Square[:b, 4]])
        engine.offer_draw
        engine.play_turn(MovePieceEvent[nil, Square[:b, 7], Square[:b, 5]])
        engine.accept_draw

        expect(listener).to have_received(:on_game_update).with(
          an_instance_of(GameUpdate).and(
            have_attributes(endgame_status: GameOutcome[:draw, :agreement])
          )
        )
      end

      context 'errors' do
        it 'returns error when offering a draw again on the same turn' do
          engine.offer_draw
          engine.offer_draw

          expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:draw_offer_not_allowed)).ordered
        end
        it 'returns error when accepting a draw after it was rejected' do
          engine.offer_draw
          engine.play_turn(MovePieceEvent[nil, Square[:b, 2], Square[:b, 4]])
          engine.play_turn(MovePieceEvent[nil, Square[:b, 7], Square[:b, 5]])
          engine.play_turn(MovePieceEvent[nil, Square[:d, 2], Square[:d, 4]])
          engine.accept_draw

          expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:draw_accept_not_allowed)).ordered
        end

        it 'returns error when accepting a draw comes before offering it' do
          engine.accept_draw
          engine.play_turn(MovePieceEvent[nil, Square[:b, 2], Square[:b, 4]])
          engine.offer_draw
          expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:draw_accept_not_allowed)).ordered
          expect(listener).not_to have_received(:on_game_update).with(
            an_instance_of(GameUpdate).and(
              have_attributes(endgame_status: GameOutcome[:draw, :agreement])
            )
          )
        end

        it 'returns error for draw offer and acceptance by the same player' do
          engine.offer_draw
          engine.accept_draw

          expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:draw_accept_not_allowed)).ordered
        end

        it 'returns error for draw offer in a game that has already ended' do
          ended_game_engine.offer_draw
          expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:game_already_ended)).ordered
        end

        it 'returns errors for draw acceptance in a game that has already ended' do
          fools_mate = [
            MovePieceEvent[nil, Square[:f, 2], Square[:f, 3]],
            MovePieceEvent[nil, Square[:e, 7], Square[:e, 6]],
            MovePieceEvent[nil, Square[:g, 2], Square[:g, 4]],
            MovePieceEvent[Piece[:black, :queen], Square[:d, 8], Square[:h, 4]]
          ]
          3.times { engine.play_turn(fools_mate[it]) }
          engine.offer_draw
          engine.play_turn(fools_mate.last) # checkmate
          engine.accept_draw

          expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:game_already_ended))
        end

        it 'does not advance the engine after a failure' do
          prev = engine.last_update
          engine.accept_draw
          expect(engine.last_update).to eq(prev)
        end
      end
    end

    context '#claim_draw' do
      it 'ends in a draw when draw claim is possible' do
        position = Position.start.with(castling_rights: CastlingRights.none, halfmove_clock: 100)
        engine = engine_from_state(GameState.load(position))
        result = engine.claim_draw
        expect(result.endgame_status).to eq(GameOutcome[:draw, :fifty_move])
      end

      it 'returns error when player is not eligible' do
        engine.claim_draw
        expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:draw_claim_not_allowed))
      end

      it 'returns error for a game that has already ended' do
        ended_game_engine.claim_draw
        expect(listener).to have_received(:on_game_update).with(GameUpdate.failure(:game_already_ended))
      end
    end
  end

  describe '#resign' do
    it 'ends the game when player resigns' do
      engine.resign
      expect(listener).to have_received(:on_game_update).with(
        an_instance_of(GameUpdate).and(
          have_attributes(endgame_status: GameOutcome[:black, :resignation])
        )
      )
    end

    it "doesn't change the outcome of a game that has already ended" do
      ended_game_engine.resign
      expect(listener).not_to have_received(:on_game_update).with(
        an_instance_of(GameUpdate).and(
          have_attributes(endgame_status: GameOutcome[:white, :resignation])
        )
      )
    end
  end

  describe 'session management' do
    def a_new_session
      satisfy('be a new session') { |update| update&.session&.new? }
    end

    def an_ongoing_session
      satisfy('be an ongoing session') { |update| !update&.session&.new? }
    end

    it 'returns an error when a move is played with no active session' do
      engine = Engine.new
      result = engine.play_turn(MovePieceEvent[nil, Square[:f, 2], Square[:f, 3]])
      expect(result.error).to eq(:no_ongoing_session)
    end

    it 'returns an error when another action is performed(draw offer, etc) with no active session' do
      engine = Engine.new
      actions = [
        engine.offer_draw,
        engine.accept_draw,
        engine.resign
      ]

      actions.each do |result|
        expect(result.error).to eq(:no_ongoing_session)
      end
    end

    it 'marks the session as new immediately after starting the first game' do
      expect(listener).to have_received(:on_game_update).with(a_new_session)
    end

    it 'marks the session as ongoing after the first move' do
      engine.play_turn(MovePieceEvent[nil, Square[:f, 2], Square[:f, 3]])
      expect(listener).to have_received(:on_game_update).with(an_ongoing_session)
    end

    it 'starts a new distinct session when a new game begins after an existing one' do
      prev_session_result = engine.play_turn(MovePieceEvent[nil, Square[:f, 2], Square[:f, 3]])
      prev_session = prev_session_result.session

      engine.new_game
      current_session = engine.last_update.session

      # one for each session
      expect(listener).to have_received(:on_game_update).with(a_new_session).twice
      expect(current_session).not_to eq(prev_session)
    end
  end
end
