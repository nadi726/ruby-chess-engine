# frozen_string_literal: true

require 'game_state/game_state'
require 'data_definitions/events'
require 'data_definitions/square'
require 'data_definitions/piece'

# For the given `GameState`, determine whether a square is occupied by a certian piece
RSpec::Matchers.define :have_piece_at do |sq, expected_piece|
  match do |actual_state|
    actual_piece = actual_state.query.board.get(sq)
    actual_piece == expected_piece
  end

  failure_message do |actual_state|
    actual_piece = actual_state.query.board.get(sq)
    "Expected #{sq} to have #{expected_piece || 'empty'}, but got #{actual_piece || 'empty'}"
  end
end

RSpec::Matchers.define :be_empty_at do |sq|
  match do |actual_state|
    have_piece_at(sq, nil).matches?(actual_state)
  end
end

RSpec.describe GameState do
  describe '#apply_event' do
    describe 'board advancement' do
      context 'simple moves' do
        it 'applies a sequence of simple moves correctly' do
          piece_from_to = [
            ['b2 b3', Piece[:white, :pawn]],
            ['g7 g5', Piece[:black, :pawn]],
            ['h2 h4', Piece[:white, :pawn]],
            ['b8 a6', Piece[:black, :knight]],
            ['h1 h3', Piece[:white, :rook]]
          ].map { |squares, piece| [piece] + parse_squares(squares) }

          gamestate = start_state
          piece_from_to.each do |piece, from, to|
            event = MovePieceEvent[piece, from, to]
            gamestate = gamestate.apply_event(event)
            expect(gamestate).to have_piece_at(to, piece)
          end
        end

        it 'moves pieces to empty squares' do
          [
            { from: Square[:b, 1], to: Square[:a, 3], piece: Piece[:white, :knight] },
            { from: Square[:e, 2], to: Square[:e, 3], piece: Piece[:white, :pawn] },
            { from: Square[:g, 2], to: Square[:g, 4], piece: Piece[:white, :pawn] }
          ].each do |tc|
            event = MovePieceEvent[tc[:piece], tc[:from], tc[:to]]
            gamestate = start_state.apply_event(event)
            expect(gamestate).to be_empty_at(tc[:from])
            expect(gamestate).to have_piece_at(tc[:to], tc[:piece])
          end
        end
      end

      context 'captures' do
        let(:board) do
          fill_board [
            [Piece[:white, :pawn], Square[:e, 4]],
            [Piece[:black, :pawn], Square[:e, 5]],
            [Piece[:white, :pawn], Square[:d, 4]],
            [Piece[:black, :pawn], Square[:d, 5]],
            [Piece[:white, :knight], Square[:f, 3]],
            [Piece[:black, :bishop], Square[:g, 4]],
            [Piece[:white, :bishop], Square[:c, 4]],
            [Piece[:black, :queen], Square[:b, 6]],
            [Piece[:white, :king], Square[:e, 1]],
            [Piece[:black, :king], Square[:e, 8]]
          ]
        end
        let(:capture_state) { GameState.new(position: Position.start.with(board: board)) }

        [
          {
            description: 'white pawn capturing black pawn',
            from: Square[:e, 4],
            to: Square[:d, 5],
            capturing_piece: Piece[:white, :pawn],
            captured_piece: Piece[:black, :pawn]
          },
          {
            description: 'white knight capturing black bishop',
            from: Square[:f, 3],
            to: Square[:g, 4],
            capturing_piece: Piece[:white, :knight],
            captured_piece: Piece[:black, :bishop]
          },
          {
            description: 'white bishop capturing black pawn',
            from: Square[:c, 4],
            to: Square[:d, 5],
            capturing_piece: Piece[:white, :bishop],
            captured_piece: Piece[:black, :pawn]
          }
        ].each do |params|
          it "allows a #{params[:description]}" do
            gamestate = capture_state.apply_event(
              MovePieceEvent[params[:capturing_piece], params[:from], params[:to]]
              .capture(params[:to], params[:captured_piece])
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
            state ||= GameState.new(position: Position.start.with(board: initial_board))
            new_state = state.apply_event(event)
            expect(new_state).to have_piece_at(event.king_to, Piece[event.color, :king])
            expect(new_state).to have_piece_at(event.rook_to, Piece[event.color, :rook])
            expect(new_state).to be_empty_at(event.king_from)
            expect(new_state).to be_empty_at(event.rook_from)
          end

          it 'applies kingside castling directly (unit)' do
            board = fill_board(
              [
                [Piece[:white, :king], Square[:e, 1]],
                [Piece[:white, :rook], Square[:h, 1]],
                [Piece[:black, :king], Square[:e, 8]]
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
                [Piece[:white, :king], Square[:e, 1]],
                [Piece[:white, :rook], Square[:a, 1]],
                [Piece[:black, :king], Square[:e, 8]]
              ]
            )
            expect_castling_on(
              event: CastlingEvent[:white, :queenside],
              initial_board: board
            )
          end

          it 'executes kingside castling via move sequence (integration)' do
            event_history = [
              MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[:f, 3]],
              MovePieceEvent[Piece[:black, :pawn], Square[:h, 7], Square[:h, 6]],
              MovePieceEvent[Piece[:white, :pawn], Square[:e, 2], Square[:e, 3]],
              MovePieceEvent[Piece[:black, :pawn], Square[:b, 7], Square[:b, 5]],
              MovePieceEvent[Piece[:white, :bishop], Square[:f, 1], Square[:e, 2]],
              MovePieceEvent[Piece[:black, :pawn], Square[:a, 7], Square[:a, 5]]
            ]

            state = event_history.reduce(start_state) { |state, event| state.apply_event(event) }
            expect_castling_on(
              event: CastlingEvent[:white, :kingside],
              initial_board: state.query.board,
              state: state
            )
          end
        end
        context 'applies en passant correctly' do
          let(:en_passant_event) { EnPassantEvent[:white, Square[:e, 5], Square[:d, 6]] }

          def expect_en_passant_applied(gamestate)
            expect(gamestate).to be_empty_at(Square[:e, 5])
            expect(gamestate).to be_empty_at(Square[:d, 5])
            expect(gamestate).to have_piece_at(Square[:d, 6], Piece[:white, :pawn])
          end

          it 'handles the event directly (unit)' do
            board = start_board
                    .move(Square[:e, 2], Square[:e, 5])
                    .move(Square[:d, 7], Square[:d, 5])
            black_pawn_move = MovePieceEvent[Piece[:black, :pawn], Square[:d, 7], Square[:d, 5]]
            # Realistically, the en passant validity is pre-computed from the target,
            # so this is unnecessary, but added here for good measure
            move_history = Immutable::List[black_pawn_move]

            gamestate = GameState.new(position: Position.start.with(board: board, en_passant_target: Square[:d, 6]),
                                      move_history: move_history)
            gamestate = gamestate.apply_event(en_passant_event)

            expect_en_passant_applied(gamestate)
          end

          it 'works through real move sequence (integration)' do
            event_history = [
              MovePieceEvent[Piece[:white, :pawn], Square[:e, 2], Square[:e, 4]],
              MovePieceEvent[Piece[:black, :pawn], Square[:c, 7], Square[:c, 5]],
              MovePieceEvent[Piece[:white, :pawn], Square[:e, 4], Square[:e, 5]],
              MovePieceEvent[Piece[:black, :pawn], Square[:d, 7], Square[:d, 5]]
            ]

            gamestate = event_history.reduce(start_state) { |state, event| state.apply_event(event) }
            gamestate = gamestate.apply_event(en_passant_event)

            expect_en_passant_applied(gamestate)
          end
        end
      end
    end

    describe 'castling rights updates' do
      it 'revokes castling rights when king moves' do
        board = start_board
                .move(Square[:e, 2], Square[:e, 5])
                .move(Square[:d, 7], Square[:d, 5])
                .move(Square[:b, 1], Square[:a, 3])
        black_king_move = MovePieceEvent[Piece[:black, :king], Square[:e, 8], Square[:d, 7]]

        gamestate = GameState.new(position: Position.start.with(board: board, current_color: :black))
        gamestate = gamestate.apply_event(black_king_move)
        position = gamestate.query.position
        empty_castling_rights = CastlingRights[CastlingSides.start, CastlingSides.none]
        expect(position.castling_rights).to eq empty_castling_rights
      end

      it 'revokes correct rook side when rook moves' do
        # Clear knight and bishop so the rook can move legally
        board = start_board
                .remove(Square[:b, 1])
                .remove(Square[:c, 1])
        white_rook_move = MovePieceEvent[Piece[:white, :rook], Square[:a, 1], Square[:a, 3]]

        gamestate = GameState.new(position: Position.start.with(board: board))
        gamestate = gamestate.apply_event(white_rook_move)
        position = gamestate.query.position

        expect(position.castling_rights.white).to eq CastlingSides[kingside: true, queenside: false]
        expect(position.castling_rights.black).to eq CastlingSides.start # unchanged
      end
      it 'revokes castling rights of the other side when rook is captured' do
        board = start_board
                .remove(Square[:h, 2])
                .remove(Square[:h, 7])
        white_rook_move = MovePieceEvent[Piece[:white, :rook], Square[:h, 1], Square[:h, 8]]
                          .capture(Square[:h, 8], Piece[:black, :rook])

        gamestate = GameState.new(position: Position.start.with(board: board))
        gamestate = gamestate.apply_event(white_rook_move)
        position = gamestate.query.position

        expect(position.castling_rights.black).to eq CastlingSides[kingside: false, queenside: true]
      end

      it 'updates correctly after castling' do
        # Setup: clear path for white kingside castling
        board = start_board
                .remove(Square[:f, 1])
                .remove(Square[:g, 1])
        castling_event = CastlingEvent[:white, :kingside]

        gamestate = GameState.new(position: Position.start.with(board: board))
        gamestate = gamestate.apply_event(castling_event)
        position = gamestate.query.position

        expect(position.castling_rights.white).to eq CastlingSides.none
        expect(position.castling_rights.black).to eq CastlingSides.start # unaffected
      end
    end

    describe 'en passant target updates' do
      it 'sets en passant target after two-square pawn move' do
        move_event = MovePieceEvent[Piece[:white, :pawn], Square[:f, 2], Square[:f, 4]]
        gamestate = GameState.start.apply_event(move_event)
        position = gamestate.query.position
        expect(position.en_passant_target).to eq(Square[:f, 3])
      end
      it 'resets en passant target when not applicable' do
        move_event = MovePieceEvent[Piece[:black, :knight], Square[:g, 8], Square[:f, 6]]
        gamestate = GameState.new(position: Position.start.with(en_passant_target: Square[:d, 3],
                                                                current_color: :black))
        gamestate = gamestate.apply_event(move_event)
        position = gamestate.query.position
        expect(position.en_passant_target).to eq(nil)
      end
    end

    describe 'turn switching' do
      it 'flips current player after each move' do
        game_state = GameState.start
        current_color = -> { game_state.query.position.current_color }

        expect(current_color.call).to eq(:white)

        game_state = game_state.apply_event(
          MovePieceEvent[Piece[:white, :pawn], Square[:f, 2], Square[:f, 4]]
        )
        expect(current_color.call).to eq(:black)

        game_state = game_state.apply_event(
          MovePieceEvent[Piece[:black, :knight], Square[:g, 8], Square[:f, 6]]
        )
        expect(current_color.call).to eq(:white)
      end
    end

    describe 'other state fields' do
      describe 'halfmove clock' do
        def halfmove_clock(state) = state.query.position.halfmove_clock

        it 'increments correctly' do
          s0 = GameState.start
          s1 = s0.apply_event(MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[:f, 3]])
          s2 = s1.apply_event(MovePieceEvent[Piece[:black, :knight], Square[:b, 8], Square[:c, 6]])
          s3 = s2.apply_event(MovePieceEvent[Piece[:white, :knight], Square[:f, 3], Square[:g, 1]])

          expect(halfmove_clock(s0)).to eq 0
          expect(halfmove_clock(s1)).to eq 1
          expect(halfmove_clock(s2)).to eq 2
          expect(halfmove_clock(s3)).to eq 3
        end

        it 'resets on pawn move' do
          position = Position.start.with(halfmove_clock: 2)
          state = GameState.new(position: position)

          new_state = state.apply_event(MovePieceEvent[Piece[:white, :pawn], Square[:e, 2], Square[:e, 4]])
          expect(halfmove_clock(new_state)).to eq(0)
        end

        it 'resets on capture' do
          board = fill_board(
            [
              [Piece[:white, :pawn], Square[:e, 4]],
              [Piece[:black, :pawn], Square[:d, 5]],
              [Piece[:white, :king], Square[:e, 1]],
              [Piece[:black, :king], Square[:e, 8]]
            ]
          )

          position = Position.start.with(board: board, halfmove_clock: 10)
          state = GameState.new(position: position)

          new_state = state.apply_event(
            MovePieceEvent[Piece[:white, :pawn], Square[:e, 4], Square[:d, 5]]
            .capture(Square[:d, 5], Piece[:black, :pawn])
          )

          expect(halfmove_clock(new_state)).to eq 0
        end

        it 'resets on en passant capture' do
          board = fill_board(
            [
              [Piece[:white, :pawn], Square[:e, 5]],
              [Piece[:black, :pawn], Square[:d, 5]],
              [Piece[:white, :king], Square[:e, 1]],
              [Piece[:black, :king], Square[:e, 8]]
            ]
          )

          position = Position.start.with(board: board, en_passant_target: Square[:d, 6], halfmove_clock: 13)
          state = GameState.new(position: position)

          new_state = state.apply_event(EnPassantEvent[:white, Square[:e, 5], Square[:d, 6]])
          expect(halfmove_clock(new_state)).to eq 0
        end
      end

      context 'updates position signatures correctly' do
        it 'uses a different position signature for non matching position' do
          base_position = Position[
            board: fill_board(
              [
                [Piece[:white, :king], Square[:e, 1]],
                [Piece[:white, :rook], Square[:h, 1]],
                [Piece[:black, :king], Square[:e, 8]]
              ]
            ),
            current_color: :white,
            en_passant_target: nil,
            castling_rights: CastlingRights[
                              CastlingSides[true, false],
                              CastlingSides.none
                            ],
            halfmove_clock: 2
          ]

          alt_position = base_position.with(current_color: :black)

          gamestate1 = GameState.new(position: base_position)
                                .apply_event(MovePieceEvent[Piece[:white, :king], Square[:e, 1], Square[:e, 2]])

          gamestate2 = GameState.new(position: alt_position)
                                .apply_event(MovePieceEvent[Piece[:black, :king], Square[:e, 8], Square[:e, 7]])

          # The original position should be counted once
          expect(gamestate1.query.position_signatures.fetch(base_position.signature, 0)).to eq(1)

          # A state from a different starting `Position` should not increment the same signature
          expect(gamestate2.query.position_signatures.fetch(base_position.signature, 0)).to eq(0)
        end

        it 'increments signature count when the same position occurs again' do
          s0 = GameState.start
          base_sig = s0.query.position.signature

          s1 = s0.apply_event(MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[:f, 3]])
          s2 = s1.apply_event(MovePieceEvent[Piece[:black, :knight], Square[:b, 8], Square[:c, 6]])
          s3 = s2.apply_event(MovePieceEvent[Piece[:white, :knight], Square[:f, 3], Square[:g, 1]])
          s4 = s3.apply_event(MovePieceEvent[Piece[:black, :knight], Square[:c, 6], Square[:b, 8]])

          expect(s4.query.position.signature).to eq(base_sig)
          expect(s4.query.position_signatures.fetch(base_sig, 0)).to eq(1)

          s5 = s4.apply_event(MovePieceEvent[Piece[:white, :pawn], Square[:a, 2], Square[:a, 3]])
          expect(s5.query.position_signatures.fetch(base_sig, 0)).to eq(2)
        end
      end
    end
  end
end
