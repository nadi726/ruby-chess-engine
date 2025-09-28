# frozen_string_literal: true

require 'game_state/game_query'
require 'game_state/game_data'
require 'game_state/board'
require 'data_definitions/events'
require 'data_definitions/position'
require 'data_definitions/piece'
require 'immutable'

RSpec.describe GameQuery do
  describe '#piece_attacking?' do
  end

  describe '#piece_can_move?' do
  end

  describe '#in_check?' do
    context 'with no check' do
      it 'returns nil on game start' do
        state = GameState.start
        expect(state.query).not_to be_in_check
      end

      it 'returns nil after move events sequence' do
        event_history = [
          MovePieceEvent[Position[:g, 1], Position[:f, 3], Piece[:white, :knight]],
          MovePieceEvent[Position[:h, 7], Position[:h, 6], Piece[:black, :pawn]],
          MovePieceEvent[Position[:e, 2], Position[:e, 3], Piece[:white, :pawn]],
          MovePieceEvent[Position[:b, 7], Position[:b, 5], Piece[:black, :pawn]],
          MovePieceEvent[Position[:f, 1], Position[:e, 2], Piece[:white, :bishop]]
        ]

        state = event_history.reduce(start_state) { |state, event| state.apply_events([event]) }

        expect(state.query).not_to be_in_check
      end

      it 'returns nil if en passant is available but does not expose king to check' do
        # White pawn on e5, black pawn just moved d7->d5 (en passant possible)
        board = fill_board(
          [
            [Piece[:white, :pawn], Position[:e, 5]],
            [Piece[:black, :pawn], Position[:d, 5]],
            [Piece[:white, :king], Position[:e, 1]],
            [Piece[:black, :king], Position[:e, 8]]
          ]
        )

        gamedata = GameData.start.with(board: board, en_passant_target: Position[:d, 6])
        state = GameState.new(data: gamedata)

        expect(state.query).not_to be_in_check
      end

      it 'returns nil on minimal setup' do
        board = fill_board(
          [
            [Piece[:white, :pawn], Position[:e, 4]],
            [Piece[:black, :pawn], Position[:d, 5]],
            [Piece[:white, :king], Position[:e, 1]],
            [Piece[:black, :king], Position[:e, 8]]
          ]
        )

        gamedata = GameData.start.with(board: board)
        state = GameState.new(data: gamedata)
        expect(state.query).not_to be_in_check
      end
    end

    context 'with simple checks' do
      it 'returns :white for check by black queen' do
        board = fill_board(
          [
            [Piece[:black, :queen], Position[:e, 8]],
            [Piece[:black, :king], Position[:d, 8]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )

        gamedata = GameData.start.with(board: board)
        state = GameState.new(data: gamedata)
        expect(state.query).to be_in_check(:white)
      end

      it 'returns :white for check by black pawn' do
        board = fill_board(
          [
            [Piece[:black, :pawn], Position[:f, 2]],
            [Piece[:black, :king], Position[:d, 8]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )

        gamedata = GameData.start.with(board: board)
        state = GameState.new(data: gamedata)
        expect(state.query).to be_in_check(:white)
      end

      it 'returns :black for check by white knight' do
        board = fill_board(
          [
            [Piece[:white, :knight], Position[:e, 6]],
            [Piece[:black, :king], Position[:d, 8]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )

        gamedata = GameData.start.with(board: board, current_color: :black)
        state = GameState.new(data: gamedata)
        expect(state.query).to be_in_check(:black)
      end
    end

    context 'with blocks' do
      it 'returns nil for black queen blocked by white piece' do
        board = fill_board(
          [
            [Piece[:black, :queen], Position[:e, 8]],
            [Piece[:black, :king], Position[:d, 8]],
            [Piece[:white, :rook], Position[:e, 4]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )

        gamedata = GameData.start.with(board: board)
        state = GameState.new(data: gamedata)
        expect(state.query).not_to be_in_check
      end

      it 'returns nil for black rook blocked by black piece' do
        board = fill_board(
          [
            [Piece[:black, :rook], Position[:e, 8]],
            [Piece[:black, :king], Position[:e, 3]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )

        gamedata = GameData.start.with(board: board)
        state = GameState.new(data: gamedata)
        expect(state.query).not_to be_in_check
      end

      it 'returns nil for white bishop blocked' do
        board = fill_board(
          [
            [Piece[:white, :bishop], Position[:b, 6]],
            [Piece[:black, :pawn], Position[:c, 7]],
            [Piece[:black, :king], Position[:d, 8]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )

        gamedata = GameData.start.with(board: board, current_color: :black)
        state = GameState.new(data: gamedata)
        expect(state.query).not_to be_in_check
      end
    end

    context 'with double check' do
      it 'returns :white when king is attacked by rook and bishop simultaneously' do
        board = fill_board(
          [
            [Piece[:black, :rook], Position[:e, 8]],
            [Piece[:black, :bishop], Position[:h, 4]],
            [Piece[:black, :king], Position[:d, 8]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )

        gamedata = GameData.start.with(board: board)
        state = GameState.new(data: gamedata)
        expect(state.query).to be_in_check(:white)
      end
    end

    context 'with discovered check' do
      it 'returns :white when moving a blocking piece reveals a rook attack' do
        # Start with rook blocked
        board = fill_board(
          [
            [Piece[:black, :rook], Position[:e, 8]],
            [Piece[:white, :bishop], Position[:e, 4]],
            [Piece[:black, :king], Position[:d, 8]],
            [Piece[:white, :king], Position[:e, 1]]
          ]
        )
        gamedata = GameData.start.with(board: board)
        state = GameState.new(data: gamedata)

        # Move the blocking pawn away
        event = MovePieceEvent[Position[:e, 4], Position[:d, 5], Piece[:white, :bishop]]
        filler_event = MovePieceEvent[Position[:e, 8], Position[:e, 7], Piece[:black, :rook]]
        new_state = state.apply_events([event]).apply_events([filler_event])

        expect(new_state.query).to be_in_check(:white)
      end
    end
  end

  describe '#in_checkmate?' do
    it 'returns false when the king is not in check' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:white, :king], Position[:f, 6]]
        ]
      )

      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_checkmate
    end

    it "Detects checkmate based on move sequence(fool's mate)" do
      event_history = [
        MovePieceEvent[Position[:f, 2], Position[:f, 3], Piece[:white, :pawn]],
        MovePieceEvent[Position[:e, 7], Position[:e, 6], Piece[:black, :pawn]],
        MovePieceEvent[Position[:g, 2], Position[:g, 4], Piece[:white, :pawn]],
        MovePieceEvent[Position[:d, 8], Position[:h, 4], Piece[:black, :queen]]
      ]

      state = event_history.reduce(start_state) { |state, event| state.apply_events([event]) }

      expect(state.query).to be_in_checkmate
    end

    it 'returns true when the current player is checkmated' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:white, :queen], Position[:g, 7]],
          [Piece[:white, :king], Position[:f, 6]]
        ]
      )

      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).to be_in_checkmate
    end

    it 'returns false when the current player is not checkmated' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:white, :queen], Position[:g, 7]],
          [Piece[:white, :king], Position[:f, 6]]
        ]
      )

      gamedata = GameData.start.with(board: board, current_color: :white)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_checkmate
    end

    it 'detects checkmate in double check correctly' do
      board = fill_board(
        [
          [Piece[:black, :king],  Position[:h, 8]],
          [Piece[:white, :rook],  Position[:h, 1]],
          [Piece[:white, :queen], Position[:f, 6]],
          [Piece[:white, :knight], Position[:e, 7]],
          [Piece[:white, :king], Position[:f, 2]]
        ]
      )

      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).to be_in_checkmate
    end

    it 'detects checkmate when the only potential block is illegal due to pin' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:e, 8]],
          [Piece[:black, :rook],  Position[:e, 7]],
          [Piece[:white, :rook],  Position[:e, 1]],
          [Piece[:white, :rook], Position[:f, 2]],
          [Piece[:white, :bishop], Position[:c, 6]],
          [Piece[:white, :knight], Position[:b, 7]],
          [Piece[:white, :king], Position[:h, 1]]
        ]
      )

      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).to be_in_checkmate
    end

    it 'returns false when a legal block is available' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:white, :queen], Position[:g, 7]],
          [Piece[:white, :king], Position[:f, 6]],
          [Piece[:black, :bishop], Position[:f, 8]] # can block queen
        ]
      )
      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_checkmate
    end

    it 'returns false when the king has a legal move' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:white, :queen], Position[:h, 6]],
          [Piece[:white, :king], Position[:f, 6]]
        ]
      )
      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_checkmate
    end

    it 'returns false when the king is in stalemate' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:black, :rook], Position[:b, 6]],
          [Piece[:white, :king], Position[:a, 1]],
          [Piece[:white, :pawn], Position[:a, 2]],
          [Piece[:white, :knight], Position[:b, 1]]

        ]
      )
      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_checkmate
    end
  end

  describe '#in_stalemate?' do
    it 'returns false when the king can move' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:white, :king], Position[:f, 6]]
        ]
      )
      gamedata = GameData.start.with(board: board)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_stalemate
    end

    it 'returns false when the king is in checkmate' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:white, :queen], Position[:g, 7]],
          [Piece[:white, :king], Position[:f, 6]]
        ]
      )

      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_stalemate
    end

    it 'returns false when king cannot move but a pawn can' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:h, 8]],
          [Piece[:black, :pawn], Position[:a, 7]],
          [Piece[:white, :queen], Position[:g, 6]],
          [Piece[:white, :king], Position[:f, 6]]
        ]
      )

      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).not_to be_in_stalemate
    end

    it 'returns true for stalemate (black)' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:a, 8]],
          [Piece[:white, :king], Position[:c, 1]],
          [Piece[:white, :queen], Position[:c, 7]]

        ]
      )
      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).to be_in_stalemate
    end

    it 'returns true for stalemate (white)' do
      board = fill_board(
        [
          [Piece[:white, :king], Position[:a, 8]],
          [Piece[:black, :king], Position[:c, 1]],
          [Piece[:black, :queen], Position[:c, 7]]

        ]
      )
      gamedata = GameData.start.with(board: board)
      query = GameQuery.new(gamedata)

      expect(query).to be_in_stalemate
    end

    it 'returns true for more complex stalemate (white)' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:g, 8]],
          [Piece[:black, :bishop], Position[:a, 7]],
          [Piece[:black, :pawn], Position[:f, 4]],
          [Piece[:black, :pawn], Position[:h, 3]],
          [Piece[:white, :king], Position[:h, 1]],
          [Piece[:white, :pawn], Position[:h, 2]]
        ]
      )
      gamedata = GameData.start.with(board: board)
      query = GameQuery.new(gamedata)

      expect(query).to be_in_stalemate
    end

    it 'returns true for more complex stalemate (black)' do
      board = fill_board(
        [
          [Piece[:black, :king], Position[:a, 3]],
          [Piece[:black, :pawn], Position[:a, 4]],
          [Piece[:white, :king], Position[:b, 1]],
          [Piece[:white, :rook], Position[:b, 8]],
          [Piece[:white, :rook], Position[:d, 4]]
        ]
      )
      gamedata = GameData.start.with(board: board, current_color: :black)
      query = GameQuery.new(gamedata)

      expect(query).to be_in_stalemate
    end
  end
end
