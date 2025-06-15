# frozen_string_literal: true

require 'event_handlers'
require 'game_state'
require 'data_definitions/events'
require 'data_definitions/position'

# spec/support/custom_matchers.rb

RSpec::Matchers.define :be_a_successful_handler_result do
  match do |actual|
    actual[:success] == true
  end

  failure_message do |actual|
    "expected success, but got failure.\nError message: #{actual[:error]}"
  end
end

RSpec::Matchers.define :be_a_failed_handler_result do
  match do |actual|
    actual[:success] == false
  end

  failure_message do
    'expected failure, but got success.'
  end
end

RSpec.describe EventHandler do
  describe '#handle_events' do
    subject(:handler) { described_class.new(GameState.new) }

    context 'when an incorrect primary event is given' do
      it 'returns invalid result for invalid event type' do
        result = handler.handle_events(RemovePieceEvent.new(nil, nil), [])
        expect(result).to be_a_failed_handler_result
      end

      it 'returns invalid result for invalid pawn move' do
        result = handler.handle_events(MovePieceEvent.new(Position.new(:b, 2), Position.new(:c, 2), nil),
                                       [])
        expect(result).to be_a_failed_handler_result
      end

      it 'returns invalid result for invalid en passant' do
        result = handler.handle_events(EnPassantEvent.new(Position.new(:e, 5), Position.new(:d, 6)),
                                       [])
        expect(result).to be_a_failed_handler_result
      end

      it 'returns invalid result for invalid other piece move' do
        result = handler.handle_events(MovePieceEvent.new(Position.new(:h, 1), Position.new(:h, 3), nil),
                                       [])
        expect(result).to be_a_failed_handler_result
      end
    end

    context 'when an incorrect extra event is given' do
      it 'returns invalid result with pawn move as primary event' do
        result = handler.handle_events(MovePieceEvent.new(Position.new(:b, 2), Position.new(:b, 3), nil),
                                       [RemovePieceEvent.new(nil, nil)])
        expect(result).to be_a_failed_handler_result
      end

      it 'returns invalid result with non-pawn related event as primary event' do
        result = handler.handle_events(MovePieceEvent.new(Position.new(:b, 1), Position.new(:a, 3), nil),
                                       [RemovePieceEvent.new(nil, nil)])
        expect(result).to be_a_failed_handler_result
      end
    end

    context 'move event' do
      it 'returns valid result for 1-rank pawn move' do
        event = MovePieceEvent.new(Position.new(:d, 2), Position.new(:d, 3), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_successful_handler_result
      end

      it 'returns valid result for 2-rank pawn move' do
        event = MovePieceEvent.new(Position.new(:f, 2), Position.new(:f, 4), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_successful_handler_result
      end

      it 'returns invalid result for 3-rank pawn move' do
        event = MovePieceEvent.new(Position.new(:g, 2), Position.new(:f, 5), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_failed_handler_result
      end

      it 'returns valid result for valid knight move' do
        event = MovePieceEvent.new(Position.new(:b, 1), Position.new(:c, 3), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_successful_handler_result
      end
    end

    context 'for complex state' do
      let(:big_state) do
        GameState.new(
          white_pieces: [
            Piece.new(:white, :king, Position.new(:e, 1)),
            Piece.new(:white, :rook, Position.new(:a, 1)),
            Piece.new(:white, :pawn, Position.new(:d, 5)),
            Piece.new(:white, :knight, Position.new(:b, 1))
          ],
          black_pieces: [
            Piece.new(:black, :king, Position.new(:e, 8)),
            Piece.new(:black, :queen, Position.new(:d, 8)),
            Piece.new(:black, :pawn, Position.new(:c, 6)),
            Piece.new(:black, :rook, Position.new(:h, 8))
          ],
          current_color: :white
        )
      end

      let(:black_state) do
        GameState.new(
          white_pieces: big_state.instance_variable_get(:@white_pieces),
          black_pieces: big_state.instance_variable_get(:@black_pieces),
          current_color: :black
        )
      end

      let(:black_handler) { described_class.new(black_state) }

      subject(:handler) { described_class.new(big_state) }

      it 'allows white rook to move to a5' do
        event = MovePieceEvent.new(Position.new(:a, 1), Position.new(:a, 5), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_successful_handler_result
      end

      it 'prevents white pawn from moving to c6 (blocked by black pawn)' do
        event = MovePieceEvent.new(Position.new(:d, 5), Position.new(:c, 6), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_failed_handler_result
      end

      it 'allows white knight to jump to c3' do
        event = MovePieceEvent.new(Position.new(:b, 1), Position.new(:c, 3), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_successful_handler_result
      end

      it 'prevents white rook from moving through black queen' do
        event = MovePieceEvent.new(Position.new(:a, 1), Position.new(:d, 8), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_failed_handler_result
      end

      it 'allows black queen to capture white pawn on d5 with empty remove event' do
        event = MovePieceEvent.new(Position.new(:d, 8), Position.new(:d, 5), nil)
        result = black_handler.handle_events(event, [RemovePieceEvent.new])
        expect(result).to be_a_successful_handler_result
      end

      it 'fails when capturing but no RemovePieceEvent is given' do
        # black queen at d8, white pawn at d5
        event = MovePieceEvent.new(Position.new(:d, 8), Position.new(:d, 5), nil)
        result = black_handler.handle_events(event, [])
        expect(result).to be_a_failed_handler_result
      end

      it 'prevents black rook from moving to a1 (blocked by white rook)' do
        event = MovePieceEvent.new(Position.new(:h, 8), Position.new(:a, 1), nil)
        result = black_handler.handle_events(event, [])
        expect(result).to be_a_failed_handler_result
      end

      it 'fails when RemovePieceEvent position does not match the target square' do
        move = MovePieceEvent.new(Position.new(:d, 8), Position.new(:d, 5), nil)
        remove = RemovePieceEvent.new(Position.new(:c, 6), Piece.new(:white, :pawn, Position.new(:c, 6)))
        result = black_handler.handle_events(move, [remove])
        expect(result).to be_a_failed_handler_result
      end

      it 'fails when RemovePieceEvent piece is not actually at given position' do
        move = MovePieceEvent.new(Position.new(:d, 8), Position.new(:d, 5), nil)
        remove = RemovePieceEvent.new(Position.new(:d, 5), Piece.new(:white, :knight, Position.new(:d, 5)))
        result = black_handler.handle_events(move, [remove])
        expect(result).to be_a_failed_handler_result
      end

      it 'fails when moving from an empty square' do
        event = MovePieceEvent.new(Position.new(:c, 4), Position.new(:d, 5), nil)
        result = handler.handle_events(event, [])
        expect(result).to be_a_failed_handler_result
      end

      it 'fails when trying to move onto allied piece even with RemovePieceEvent' do
        move = MovePieceEvent.new(Position.new(:a, 1), Position.new(:d, 5), nil)
        remove = RemovePieceEvent.new(Position.new(:d, 5), Piece.new(:white, :pawn, Position.new(:d, 5)))
        result = handler.handle_events(move, [remove])
        expect(result).to be_a_failed_handler_result
      end

      it 'fails if RemovePieceEvent is given but no piece is being captured' do
        move = MovePieceEvent.new(Position.new(:a, 1), Position.new(:a, 4), nil)
        remove = RemovePieceEvent.new(Position.new(:a, 4), nil)
        result = handler.handle_events(move, [remove])
        expect(result).to be_a_failed_handler_result
      end

      it 'succeeds when a valid capture is declared correctly & fully' do
        move = MovePieceEvent.new(Position.new(:d, 8), Position.new(:d, 5), nil)
        captured = big_state.piece_at(Position.new(:d, 5))
        remove = RemovePieceEvent.new(Position.new(:d, 5), captured)
        result = black_handler.handle_events(move, [remove])
        expect(result).to be_a_successful_handler_result
      end
    end

    context 'for another complex state' do
      let(:complex_state) do
        GameState.new(
          white_pieces: [
            Piece.new(:white, :king, Position.new(:e, 1)),
            Piece.new(:white, :rook, Position.new(:a, 1)),
            Piece.new(:white, :pawn, Position.new(:d, 5)),
            Piece.new(:white, :knight, Position.new(:b, 1)),
            Piece.new(:white, :bishop, Position.new(:c, 1))
          ],
          black_pieces: [
            Piece.new(:black, :king, Position.new(:e, 8)),
            Piece.new(:black, :queen, Position.new(:d, 8)),
            Piece.new(:black, :pawn, Position.new(:a, 6)),
            Piece.new(:black, :rook, Position.new(:h, 8)),
            Piece.new(:black, :bishop, Position.new(:f, 8))
          ],
          current_color: :white
        )
      end

      let(:black_state) do
        GameState.new(
          white_pieces: [
            Piece.new(:white, :king, Position.new(:e, 1)),
            Piece.new(:white, :rook, Position.new(:a, 1)),
            Piece.new(:white, :pawn, Position.new(:d, 5)),
            Piece.new(:white, :knight, Position.new(:b, 1)),
            Piece.new(:white, :bishop, Position.new(:c, 1))
          ],
          black_pieces: [
            Piece.new(:black, :king, Position.new(:e, 8)),
            Piece.new(:black, :queen, Position.new(:d, 8)),
            Piece.new(:black, :pawn, Position.new(:c, 6)),
            Piece.new(:black, :rook, Position.new(:h, 8)),
            Piece.new(:black, :bishop, Position.new(:f, 8))
          ],
          current_color: :black
        )
      end

      subject(:handler) { described_class.new(complex_state) }
      let(:black_handler) { described_class.new(black_state) }

      context 'friendly fire prevention' do
        it 'prevents moving onto a square occupied by own piece' do
          # White knight tries to move to c1 (occupied by white bishop)
          event = MovePieceEvent.new(Position.new(:b, 1), Position.new(:c, 1), nil)
          result = handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end

        it 'prevents capturing own piece even with remove event' do
          # White rook tries to capture white pawn on d5
          move_event = MovePieceEvent.new(Position.new(:a, 1), Position.new(:d, 5), nil)
          remove_event = RemovePieceEvent.new(Position.new(:d, 5), :white)
          result = handler.handle_events(move_event, [remove_event])
          expect(result).to be_a_failed_handler_result
        end
      end

      context 'capture enforcement' do
        it 'requires remove event to capture opponent piece' do
          # White rook tries to capture black pawn on c6 without remove event
          event = MovePieceEvent.new(Position.new(:a, 1), Position.new(:a, 6), nil)
          result = handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end

        it 'allows capture with correct remove event' do
          move_event = MovePieceEvent.new(Position.new(:a, 1), Position.new(:a, 6), nil)
          remove_event = RemovePieceEvent.new(Position.new(:a, 6), nil)
          result = handler.handle_events(move_event, [remove_event])
          expect(result).to be_a_successful_handler_result
        end
      end

      context 'bishop movement and path blocking' do
        it 'allows bishop to move diagonally unobstructed' do
          # Move white bishop from c1 to e3 (assuming clear path)
          event = MovePieceEvent.new(Position.new(:c, 1), Position.new(:e, 3), nil)
          result = handler.handle_events(event, [])
          expect(result).to be_a_successful_handler_result
        end

        it 'prevents bishop moving through piece blocking path' do
          # Place a piece blocking bishop at d2
          blocking_piece = Piece.new(:white, :pawn, Position.new(:d, 2))
          complex_state.instance_variable_get(:@white_pieces) << blocking_piece

          event = MovePieceEvent.new(Position.new(:c, 1), Position.new(:e, 3), nil)
          result = handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end
      end

      context 'turn enforcement' do
        it 'prevents black from moving when it is white’s turn' do
          event = MovePieceEvent.new(Position.new(:e, 8), Position.new(:e, 7), nil)
          result = handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end

        it 'allows black to move on black’s turn' do
          event = MovePieceEvent.new(Position.new(:e, 8), Position.new(:e, 7), nil)
          result = black_handler.handle_events(event, [])
          expect(result).to be_a_successful_handler_result
        end
      end

      context 'promotion (not implemented yet)' do
        xit 'rejects pawn move to last rank without promotion' do
          # White pawn moves to rank 8 without specifying promotion
          pawn = Piece.new(:white, :pawn, Position.new(:g, 7))
          complex_state.instance_variable_get(:@white_pieces) << pawn

          event = MovePieceEvent.new(Position.new(:g, 7), Position.new(:g, 8), nil)
          result = handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end
      end

      context 'en passant' do
        before do
          white_pawn = Piece.new(:white, :pawn, Position.new(:e, 5))
          black_pawn = Piece.new(:black, :pawn, Position.new(:d, 5))
          black_pawn_move = MovePieceEvent.new(Position.new(:d, 7), Position.new(:d, 5), black_pawn)
          complex_state.instance_variable_get(:@white_pieces) << white_pawn
          complex_state.instance_variable_get(:@black_pieces) << black_pawn
          complex_state.instance_variable_get(:@move_history) << [black_pawn_move]
        end

        it 'rejects en passant without required events' do
          # Attempt en passant without RemovePieceEvent
          move_event = MovePieceEvent.new(Position.new(:e, 5), Position.new(:d, 6), nil)
          result = handler.handle_events(move_event, [])
          expect(result).to be_a_failed_handler_result
        end

        it 'accept en passant with required events from move event' do
          move_event = MovePieceEvent.new(Position.new(:e, 5), Position.new(:d, 6), nil)
          result = handler.handle_events(move_event, [RemovePieceEvent.new])
          expect(result).to be_a_successful_handler_result
        end

        it 'accept valid en passant from EnPassantEvent' do
          event = EnPassantEvent.new(Position.new(:e, 5), Position.new(:d, 6))
          result = handler.handle_events(event, [])
          expect(result).to be_a_successful_handler_result
        end

        it 'rejects en passant if last move was not a double-step pawn move' do
          # Override move history with a 1-step move
          complex_state.instance_variable_set(:@move_history, [
                                                [MovePieceEvent.new(Position.new(:d, 6), Position.new(:d, 5),
                                                                    Piece.new(:black, :pawn, Position.new(:d, 5)))]
                                              ])

          event = EnPassantEvent.new(Position.new(:e, 5), Position.new(:d, 6))
          result = handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end

        it 'rejects en passant if not immediate (other move played in between)' do
          black_double_push = MovePieceEvent.new(Position.new(:d, 7), Position.new(:d, 5),
                                                 Piece.new(:black, :pawn, Position.new(:d, 5)))
          some_other_move = MovePieceEvent.new(Position.new(:c, 1), Position.new(:e, 3),
                                               Piece.new(:white, :bishop, Position.new(:e, 3)))

          complex_state.instance_variable_set(:@move_history, [[black_double_push], [some_other_move]])

          event = EnPassantEvent.new(Position.new(:e, 5), Position.new(:d, 6))
          result = handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end

        it 'rejects en passant if it is not the right player’s turn' do
          black_state.instance_variable_get(:@move_history) <<
            [MovePieceEvent.new(Position.new(:d, 7), Position.new(:d, 5),
                                Piece.new(:black, :pawn, Position.new(:d, 5)))]

          black_handler = described_class.new(black_state) # black to move
          event = EnPassantEvent.new(Position.new(:e, 5), Position.new(:d, 6))
          result = black_handler.handle_events(event, [])
          expect(result).to be_a_failed_handler_result
        end
      end
    end
  end
end
