# frozen_string_literal: true

require 'game_state/game_state'
require 'data_definitions/events'
require 'data_definitions/position'
require 'data_definitions/piece'

RSpec.describe GameState do
  describe '#apply_events' do
    #
    # UNIT TESTS ONLY:
    # We manually provide sequences of events and verify GameState updates.
    #

    describe 'board advancement' do
      context 'simple moves' do
        it 'applies a sequence of simple moves correctly' do
          from_to_piece = [
            ['b2 b3', Piece[:white, :pawn]],
            ['g7 g5', Piece[:black, :pawn]],
            ['h2 h4', Piece[:white, :pawn]],
            ['b8 a6', Piece[:black, :knight]],
            ['h1 h3', Piece[:white, :rook]]
          ].map { |positions, piece| parse_positions(positions) + [piece] }

          gamestate = start_state
          from_to_piece.each do |from, to, piece|
            event = MovePieceEvent[from, to, piece]
            gamestate = gamestate.apply_events([event])
          end

          from_to_piece.each do |_from, to, piece| # rubocop:disable Style/CombinableLoops
            expect(gamestate).to have_piece_at(to, piece)
          end
        end

        it 'moves pieces to empty squares' do
          [
            { from: Position[:b, 1], to: Position[:a, 3], piece: Piece[:white, :knight] },
            { from: Position[:e, 2], to: Position[:e, 3], piece: Piece[:white, :pawn] },
            { from: Position[:g, 2], to: Position[:g, 4], piece: Piece[:white, :pawn] }
          ].each do |tc|
            event = MovePieceEvent[tc[:from], tc[:to], tc[:piece]]
            gamestate = start_state.apply_events([event])
            expect(gamestate).to be_empty_at(tc[:from])
            expect(gamestate).to have_piece_at(tc[:to], tc[:piece])
          end
        end
      end

      context 'captures' do
        let(:board) do
          fill_board [
            [Piece[:white, :pawn], Position[:e, 4]],
            [Piece[:black, :pawn], Position[:e, 5]],
            [Piece[:white, :pawn], Position[:d, 4]],
            [Piece[:black, :pawn], Position[:d, 5]],
            [Piece[:white, :knight], Position[:f, 3]],
            [Piece[:black, :bishop], Position[:g, 4]],
            [Piece[:white, :bishop], Position[:c, 4]],
            [Piece[:black, :queen], Position[:b, 6]],
            [Piece[:white, :king], Position[:e, 1]],
            [Piece[:black, :king], Position[:e, 8]]
          ]
        end
        let(:capture_state) { GameState.new(data: GameData.start.with(board: board)) }

        [
          {
            description: 'white pawn capturing black pawn',
            from: Position[:e, 4],
            to: Position[:d, 5],
            capturing_piece: Piece[:white, :pawn],
            captured_piece: Piece[:black, :pawn]
          },
          {
            description: 'white knight capturing black bishop',
            from: Position[:f, 3],
            to: Position[:g, 4],
            capturing_piece: Piece[:white, :knight],
            captured_piece: Piece[:black, :bishop]
          },
          {
            description: 'white bishop capturing black pawn',
            from: Position[:c, 4],
            to: Position[:d, 5],
            capturing_piece: Piece[:white, :bishop],
            captured_piece: Piece[:black, :pawn]
          }
        ].each do |params|
          it "allows a #{params[:description]}" do
            gamestate = capture_state.apply_events(
              [
                MovePieceEvent[params[:from], params[:to], params[:capturing_piece]],
                RemovePieceEvent[params[:to], params[:captured_piece]]
              ]
            )
            expect(gamestate).to be_empty_at(params[:from])
            expect(gamestate).to have_piece_at(params[:to], params[:capturing_piece])
          end
        end
      end

      context 'special moves' do
        context 'castling' do
          # Helper that runs the castling and asserts
          def expect_castling_on(event:, initial_board:, state: nil) # rubocop:disable Metrics/AbcSize
            state ||= GameState.new(data: GameData.start.with(board: initial_board))
            new_state = state.apply_events([event])
            expect(new_state).to have_piece_at(event.king_to, Piece[event.color, :king])
            expect(new_state).to have_piece_at(event.rook_to, Piece[event.color, :rook])
            expect(new_state).to be_empty_at(event.king_from)
            expect(new_state).to be_empty_at(event.rook_from)
          end

          it 'applies kingside castling directly (unit)' do
            board = fill_board(
              [
                [Piece[:white, :king], Position[:e, 1]],
                [Piece[:white, :rook], Position[:h, 1]],
                [Piece[:black, :king], Position[:e, 8]]
              ]
            )

            expect_castling_on(
              event: CastlingEvent[:white, :kingside],
              initial_board: board
            )
          end

          it 'applies queenside castling directly (unit)' do
            board = fill_board(
              [
                [Piece[:white, :king], Position[:e, 1]],
                [Piece[:white, :rook], Position[:a, 1]],
                [Piece[:black, :king], Position[:e, 8]]
              ]
            )
            expect_castling_on(
              event: CastlingEvent[:white, :queenside],
              initial_board: board
            )
          end

          it 'executes kingside castling via move sequence (integration)' do
            event_history = [
              MovePieceEvent[Position[:g, 1], Position[:f, 3], Piece[:white, :knight]],
              MovePieceEvent[Position[:h, 7], Position[:h, 6], Piece[:black, :pawn]],
              MovePieceEvent[Position[:e, 2], Position[:e, 3], Piece[:white, :pawn]],
              MovePieceEvent[Position[:b, 7], Position[:b, 5], Piece[:black, :pawn]],
              MovePieceEvent[Position[:f, 1], Position[:e, 2], Piece[:white, :bishop]],
              MovePieceEvent[Position[:a, 7], Position[:a, 5], Piece[:black, :pawn]]
            ]

            state = event_history.reduce(start_state) { |state, event| state.apply_events([event]) }
            expect_castling_on(
              event: CastlingEvent[:white, :kingside],
              initial_board: state.query.board,
              state: state
            )
          end
        end
        context 'applies en passant correctly' do
          let(:en_passant_sequence) { [EnPassantEvent[Position[:e, 5], Position[:d, 6]]] }

          def expect_en_passant_applied(gamestate)
            expect(gamestate).to be_empty_at(Position[:e, 5])
            expect(gamestate).to be_empty_at(Position[:d, 5])
            expect(gamestate).to have_piece_at(Position[:d, 6], Piece[:white, :pawn])
          end

          it 'handles the event directly (unit)' do
            board = start_board
                    .move(Position[:e, 2], Position[:e, 5])
                    .move(Position[:d, 7], Position[:d, 5])
            black_pawn_move = MovePieceEvent[Position[:d, 7], Position[:d, 5], Piece[:black, :pawn]]
            # Realistically, the en passant validity is pre-computed from the target,
            # so this is unnecessary, but added here for good measure
            move_history = Immutable::List[Immutable::List[black_pawn_move]]

            gamestate = GameState.new(data: GameData.start.with(board: board, en_passant_target: Position[:d, 6]),
                                      move_history: move_history)
            gamestate = gamestate.apply_events(en_passant_sequence)

            expect_en_passant_applied(gamestate)
          end

          it 'works through real move sequence (integration)' do
            event_history = [
              MovePieceEvent[Position[:e, 2], Position[:e, 4], Piece[:white, :pawn]],
              MovePieceEvent[Position[:c, 7], Position[:c, 5], Piece[:black, :pawn]],
              MovePieceEvent[Position[:e, 4], Position[:e, 5], Piece[:white, :pawn]],
              MovePieceEvent[Position[:d, 7], Position[:d, 5], Piece[:black, :pawn]]
            ]

            gamestate = event_history.reduce(start_state) { |state, event| state.apply_events([event]) }
            gamestate = gamestate.apply_events(en_passant_sequence)

            expect_en_passant_applied(gamestate)
          end
        end
      end
    end

    describe 'castling rights updates' do
      it 'revokes castling rights when king moves' do
        board = start_board
                .move(Position[:e, 2], Position[:e, 5])
                .move(Position[:d, 7], Position[:d, 5])
                .move(Position[:b, 1], Position[:a, 3])
        black_king_move = MovePieceEvent[Position[:e, 8], Position[:d, 7], Piece[:black, :king]]

        gamestate = GameState.new(data: GameData.start.with(board: board, current_color: :black))
        gamestate = gamestate.apply_events([black_king_move])
        data = gamestate.query.data
        empty_castling_rights = CastlingRights[CastlingSide[true, true], CastlingSide[false, false]]
        expect(data.castling_rights).to eq empty_castling_rights
      end
      it 'revokes correct rook side when rook moves' do
        # Clear knight and bishop so the rook can move legally
        board = start_board
                .remove(Position[:b, 1])
                .remove(Position[:c, 1])
        white_rook_move = MovePieceEvent[Position[:a, 1], Position[:a, 3], Piece[:white, :rook]]

        gamestate = GameState.new(data: GameData.start.with(board: board))
        gamestate = gamestate.apply_events([white_rook_move])
        data = gamestate.query.data

        expect(data.castling_rights.white).to eq CastlingSide[kingside: true, queenside: false]
        expect(data.castling_rights.black).to eq CastlingSide[true, true] # unchanged
      end
      it 'updates correctly after castling' do
        # Setup: clear path for white kingside castling
        board = start_board
                .remove(Position[:f, 1])
                .remove(Position[:g, 1])
        castling_event = CastlingEvent[:white, :kingside]

        gamestate = GameState.new(data: GameData.start.with(board: board))
        gamestate = gamestate.apply_events([castling_event])
        data = gamestate.query.data

        expect(data.castling_rights.white).to eq CastlingSide[false, false]
        expect(data.castling_rights.black).to eq CastlingSide[true, true] # unaffected
      end
    end

    describe 'en passant target updates' do
      it 'sets en passant target after two-square pawn move' do
        move_event = MovePieceEvent[Position[:f, 2], Position[:f, 4], Piece[:white, :pawn]]
        gamestate = GameState.start.apply_events([move_event])
        data = gamestate.query.data
        expect(data.en_passant_target).to eq(Position[:f, 3])
      end
      it 'resets en passant target when not applicable' do
        move_event = MovePieceEvent[Position[:g, 8], Position[:f, 6], Piece[:black, :knight]]
        gamestate = GameState.new(data: GameData.start.with(en_passant_target: Position[:d, 3],
                                                            current_color: :black))
        gamestate = gamestate.apply_events([move_event])
        data = gamestate.query.data
        expect(data.en_passant_target).to eq(nil)
      end
    end

    describe 'turn switching' do
      it 'flips current player after each move' do
        game_state = GameState.start
        current_color = -> { game_state.query.data.current_color }

        expect(current_color.call).to eq(:white)

        game_state = game_state.apply_events(
          [MovePieceEvent[Position[:f, 2], Position[:f, 4], Piece[:white, :pawn]]]
        )
        expect(current_color.call).to eq(:black)

        game_state = game_state.apply_events(
          [MovePieceEvent[Position[:g, 8], Position[:f, 6], Piece[:black, :knight]]]
        )
        expect(current_color.call).to eq(:white)
      end
    end

    describe 'other state fields' do
      describe 'halfmove clock' do
        def halfmove_clock(state) = state.query.data.halfmove_clock

        it 'increments correctly' do
          s0 = GameState.start
          s1 = s0.apply_events([MovePieceEvent[Position[:g, 1], Position[:f, 3], Piece[:white, :knight]]])
          s2 = s1.apply_events([MovePieceEvent[Position[:b, 8], Position[:c, 6], Piece[:black, :knight]]])
          s3 = s2.apply_events([MovePieceEvent[Position[:f, 3], Position[:g, 1], Piece[:white, :knight]]])

          expect(halfmove_clock(s0)).to eq 0
          expect(halfmove_clock(s1)).to eq 1
          expect(halfmove_clock(s2)).to eq 2
          expect(halfmove_clock(s3)).to eq 3
        end

        it 'resets on pawn move' do
          gamedata = GameData.start.with(halfmove_clock: 2)
          state = GameState.new(data: gamedata)

          new_state = state.apply_events([MovePieceEvent[Position[:e, 2], Position[:e, 4],
                                                         Piece[:white, :pawn]]])
          expect(halfmove_clock(new_state)).to eq(0)
        end

        it 'resets on capture' do
          board = fill_board(
            [
              [Piece[:white, :pawn], Position[:e, 4]],
              [Piece[:black, :pawn], Position[:d, 5]],
              [Piece[:white, :king], Position[:e, 1]],
              [Piece[:black, :king], Position[:e, 8]]
            ]
          )

          gamedata = GameData.start.with(board: board, halfmove_clock: 10)
          state = GameState.new(data: gamedata)

          new_state = state.apply_events(
            [
              MovePieceEvent[Position[:e, 4], Position[:d, 5], Piece[:white, :pawn]],
              RemovePieceEvent[Position[:d, 5], Piece[:black, :pawn]]
            ]
          )

          expect(halfmove_clock(new_state)).to eq 0
        end

        it 'resets on en passant capture' do
          board = fill_board(
            [
              [Piece[:white, :pawn], Position[:e, 5]],
              [Piece[:black, :pawn], Position[:d, 5]],
              [Piece[:white, :king], Position[:e, 1]],
              [Piece[:black, :king], Position[:e, 8]]
            ]
          )

          gamedata = GameData.start.with(board: board, en_passant_target: Position[:d, 6], halfmove_clock: 13)
          state = GameState.new(data: gamedata)

          new_state = state.apply_events([EnPassantEvent[Position[:e, 5], Position[:d, 6]]])

          expect(halfmove_clock(new_state)).to eq 0
        end
      end

      context 'updates position signatures correctly' do
        it 'uses a different position signature for non matching data' do
          base_data = GameData[
            board: fill_board(
              [
                [Piece[:white, :king], Position[:e, 1]],
                [Piece[:white, :rook], Position[:h, 1]],
                [Piece[:black, :king], Position[:e, 8]]
              ]
            ),
            current_color: :white,
            en_passant_target: nil,
            castling_rights: CastlingRights[
                              CastlingSide[true, false],
                              CastlingSide[false, false]
                            ],
            halfmove_clock: 2
          ]

          alt_data = base_data.with(current_color: :black)

          gamestate1 = GameState.new(data: base_data)
                                .apply_events([MovePieceEvent[Position[:e, 1], Position[:e, 2], Piece[:white, :king]]])

          gamestate2 = GameState.new(data: alt_data)
                                .apply_events([MovePieceEvent[Position[:e, 8], Position[:e, 7], Piece[:black, :king]]])

          # The original position should be counted once
          expect(gamestate1.query.position_signatures.fetch(base_data.position_signature, 0)).to eq(1)

          # A state from a different starting GameData should not increment the same signature
          expect(gamestate2.query.position_signatures.fetch(base_data.position_signature, 0)).to eq(0)
        end

        it 'increments signature count when the same position occurs again' do
          s0 = GameState.start
          base_sig = s0.query.data.position_signature

          s1 = s0.apply_events([MovePieceEvent[Position[:g, 1], Position[:f, 3], Piece[:white, :knight]]])
          s2 = s1.apply_events([MovePieceEvent[Position[:b, 8], Position[:c, 6], Piece[:black, :knight]]])
          s3 = s2.apply_events([MovePieceEvent[Position[:f, 3], Position[:g, 1], Piece[:white, :knight]]])
          s4 = s3.apply_events([MovePieceEvent[Position[:c, 6], Position[:b, 8], Piece[:black, :knight]]])

          expect(s4.query.data.position_signature).to eq(base_sig)
          expect(s4.query.position_signatures.fetch(base_sig, 0)).to eq(1)

          s5 = s4.apply_events([MovePieceEvent[Position[:a, 2], Position[:a, 3], Piece[:white, :pawn]]])
          expect(s5.query.position_signatures.fetch(base_sig, 0)).to eq(2)
        end
      end
    end
  end
end
