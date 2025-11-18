# frozen_string_literal: true

require 'game_state/game_query'
require 'game_state/position'
require 'game_state/board'
require 'data_definitions/events'
require 'data_definitions/square'
require 'data_definitions/piece'
require 'immutable'

RSpec.describe GameQuery do
  describe 'with invalid arguments' do
    let(:valid_square) { Square[:e, 1] }
    let(:invalid_squares) { [nil, :e3, Square[:x, 1]] }
    let(:invalid_colors) { [nil, 4, :pink, :blaaack] }

    it 'for #piece_can_move?' do
      invalid_squares.each do |invalid_square|
        expect(start_query.piece_can_move?(invalid_square, valid_square)).to eq(GameQuery::INVALID_ARGUMENT)
        expect(start_query.piece_can_move?(valid_square, invalid_square)).to eq(GameQuery::INVALID_ARGUMENT)
      end
    end

    it 'for #piece_attacking?' do
      invalid_squares.each do |invalid_square|
        expect(start_query.piece_attacking?(invalid_square, valid_square)).to eq(GameQuery::INVALID_ARGUMENT)
        expect(start_query.piece_attacking?(valid_square, invalid_square)).to eq(GameQuery::INVALID_ARGUMENT)
      end
    end

    it 'for #square_attacked?' do
      invalid_squares.each do |invalid_square|
        expect(start_query.square_attacked?(invalid_square, :white)).to eq(GameQuery::INVALID_ARGUMENT)
      end

      invalid_colors.each do |invalid_color|
        expect(start_query.square_attacked?(invalid_color)).to eq(GameQuery::INVALID_ARGUMENT)
      end
    end

    it 'for #legal moves' do
      invalid_colors.each do |invalid_color|
        expect(start_query.legal_moves(invalid_color)).to eq(GameQuery::INVALID_ARGUMENT)
      end
    end

    it 'for #in_check?' do
      invalid_colors.each do |invalid_color|
        expect(start_query.in_check?(invalid_color)).to eq(GameQuery::INVALID_ARGUMENT)
      end
    end
  end

  describe '#piece_can_move?' do
    it 'returns true for valid start and end squares' do
      expect(start_query.piece_can_move?(Square[:e, 2], Square[:e, 3])).to eq(true)
    end

    it 'returns false when there is no piece at starting square' do
      expect(start_query.piece_can_move?(Square[:f, 5], Square[:f, 6])).to eq(false)
    end

    it 'returns false when the piece cannot even geometrically move to the end square' do
      expect(start_query.piece_can_move?(Square[:e, 2], Square[:e, 6])).to eq(false)
    end

    it 'returns false when the path to the end square is blocked' do
      expect(start_query.piece_can_move?(Square[:a, 8], Square[:a, 3])).to eq(false)
    end

    it 'returns false when end square is occupied' do
      expect(start_query.piece_can_move?(Square[:g, 1], Square[:e, 2])).to eq(false)
    end
  end

  describe '#piece_attacking?' do
    it 'returns true for valid attack' do
      expect(start_query.piece_attacking?(Square[:g, 2], Square[:h, 3])).to eq(true)
    end
    it 'returns false when the piece cannot "geometrically capture" the square' do
      expect(start_query.piece_attacking?(Square[:e, 2], Square[:h, 3])).to eq(false)
    end

    it 'returns false when the path is blocked' do
      expect(start_query.piece_attacking?(Square[:h, 1], Square[:h, 6])).to eq(false)
    end

    it 'returns false when target square is occupied by a piece of the same color' do
      expect(start_query.piece_attacking?(Square[:f, 8], Square[:e, 7])).to eq(false)
    end
  end

  describe '#square_attacked?' do
    it 'returns true for an empty square attacked by either color' do
      expect(start_query.square_attacked?(Square[:h, 3], :white)).to eq(true)
      expect(start_query.square_attacked?(Square[:h, 6], :black)).to eq(true)
    end

    it 'returns true for an occupied square attacked by a piece of the other color' do
      new_board = start_board.insert(Piece[:white, :queen], Square[:a, 6])
      query = GameQuery.new(Position.start.with(board: new_board))
      expect(query.square_attacked?(Square[:a, 6], :black)).to eq(true)
      expect(query.square_attacked?(Square[:a, 6], :white)).to eq(false)
    end

    it 'returns false for an empty square not attacked by color' do
      expect(start_query.square_attacked?(Square[:d, 4], :white)).to eq(false)
      expect(start_query.square_attacked?(Square[:d, 4], :black)).to eq(false)
    end

    it 'returns false for an occupied square with piece of the same color' do
      expect(start_query.square_attacked?(Square[:f, 1], :white)).to eq(false)
    end
  end

  describe '#legal moves' do
    it 'returns all legal moves from starting position' do
      legal_moves = start_query.legal_moves(:white)

      # pawns
      Square::FILES.each do |file|
        one_rank_move = MovePieceEvent[Piece[:white, :pawn], Square[file, 2], Square[file, 3]]
        two_ranks_move = one_rank_move.with(to: Square[file, 4])
        expect(legal_moves).to include(one_rank_move, two_ranks_move)
      end

      knight1_moves = %i[a c].map do |to_file|
        MovePieceEvent[Piece[:white, :knight], Square[:b, 1], Square[to_file, 3]]
      end
      knight2_moves = %i[f h].map do |to_file|
        MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[to_file, 3]]
      end

      expect(legal_moves).to include(*(knight1_moves + knight2_moves))
    end

    it 'returns empty enumerable when there are no legal moves' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:a, 8]],
          [Piece[:white, :king], Square[:c, 1]],
          [Piece[:white, :queen], Square[:c, 7]]

        ]
      )
      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query.legal_moves(:black)).to be_none
    end
    it 'returns special moves when available' do
      # Setup a single position with promotion, capture, castling and enpassant available
      board = fill_board(
        [
          [Piece[:white, :king], Square[:e, 1]],
          [Piece[:white, :rook], Square[:h, 1]],
          [Piece[:white, :pawn], Square[:c, 5]],
          [Piece[:white, :pawn], Square[:g, 7]],
          [Piece[:black, :king], Square[:a, 8]],
          [Piece[:black, :rook], Square[:d, 2]],
          [Piece[:black, :pawn], Square[:b, 5]]
        ]
      )
      castling_rights = CastlingRights[white: CastlingSides[true, false], black: CastlingSides.none]
      position = Position[board: board, current_color: :white, en_passant_target: Square[:b, 6],
                          castling_rights: castling_rights, halfmove_clock: 20]
      history = GameHistory[moves: [MovePieceEvent[Piece[:black, :pawn], Square[:b, 7], Square[:b, 5]]]]
      query = GameQuery.new(position, history)

      events = [
        MovePieceEvent[Piece[:white, :pawn], Square[:g, 7], Square[:g, 8]].promote(:queen),
        MovePieceEvent[Piece[:white, :king], Square[:e, 1], Square[:d, 2]]
          .capture(Square[:d, 2], Piece[:black, :rook]),
        CastlingEvent[:white, :kingside],
        EnPassantEvent[:white, Square[:c, 5], Square[:b, 6]]
      ]
      expect(query.legal_moves(:white)).to include(*events)
    end
  end

  describe '#in_check?' do
    context 'with no check' do
      it 'returns false on game start' do
        state = GameState.start
        expect(state.query).not_to be_in_check
      end

      it 'returns false after move events sequence' do
        event_history = [
          MovePieceEvent[Piece[:white, :knight], Square[:g, 1], Square[:f, 3]],
          MovePieceEvent[Piece[:black, :pawn], Square[:h, 7], Square[:h, 6]],
          MovePieceEvent[Piece[:white, :pawn], Square[:e, 2], Square[:e, 3]],
          MovePieceEvent[Piece[:black, :pawn], Square[:b, 7], Square[:b, 5]],
          MovePieceEvent[Piece[:white, :bishop], Square[:f, 1], Square[:e, 2]]
        ]

        state = event_history.reduce(GameState.new(position:
        Position.start.with(castling_rights: CastlingRights.none))) do |state, event|
          state.apply_event(event)
        end

        expect(state.query).not_to be_in_check
      end

      it 'returns false if en passant is available but does not expose king to check' do
        # White pawn on e5, black pawn just moved d7->d5 (en passant possible)
        board = fill_board(
          [
            [Piece[:white, :pawn], Square[:e, 5]],
            [Piece[:black, :pawn], Square[:d, 5]],
            [Piece[:white, :king], Square[:e, 1]],
            [Piece[:black, :king], Square[:e, 8]]
          ]
        )

        position = Position.start.with(board: board, en_passant_target: Square[:d, 6],
                                       castling_rights: CastlingRights.none)
        state = GameState.new(position: position)

        expect(state.query).not_to be_in_check
      end

      it 'returns false on minimal setup' do
        board = fill_board(
          [
            [Piece[:white, :pawn], Square[:e, 4]],
            [Piece[:black, :pawn], Square[:d, 5]],
            [Piece[:white, :king], Square[:e, 1]],
            [Piece[:black, :king], Square[:e, 8]]
          ]
        )

        position = Position.start.with(board: board, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).not_to be_in_check
      end
    end

    context 'with simple checks' do
      it 'returns true for check by black queen' do
        board = fill_board(
          [
            [Piece[:black, :queen], Square[:e, 8]],
            [Piece[:black, :king], Square[:d, 8]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )

        position = Position.start.with(board: board, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).to be_in_check(:white)
      end

      it 'returns true for check by black pawn' do
        board = fill_board(
          [
            [Piece[:black, :pawn], Square[:f, 2]],
            [Piece[:black, :king], Square[:d, 8]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )

        position = Position.start.with(board: board, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).to be_in_check(:white)
      end

      it 'returns true for check by white knight' do
        board = fill_board(
          [
            [Piece[:white, :knight], Square[:e, 6]],
            [Piece[:black, :king], Square[:d, 8]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )

        position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).to be_in_check(:black)
      end
    end

    context 'with blocks' do
      it 'returns false for black queen blocked by white piece' do
        board = fill_board(
          [
            [Piece[:black, :queen], Square[:e, 8]],
            [Piece[:black, :king], Square[:d, 8]],
            [Piece[:white, :rook], Square[:e, 4]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )

        position = Position.start.with(board: board, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).not_to be_in_check
      end

      it 'returns false for black rook blocked by black piece' do
        board = fill_board(
          [
            [Piece[:black, :rook], Square[:e, 8]],
            [Piece[:black, :king], Square[:e, 3]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )

        position = Position.start.with(board: board, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).not_to be_in_check
      end

      it 'returns false for white bishop blocked' do
        board = fill_board(
          [
            [Piece[:white, :bishop], Square[:b, 6]],
            [Piece[:black, :pawn], Square[:c, 7]],
            [Piece[:black, :king], Square[:d, 8]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )

        position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).not_to be_in_check
      end
    end

    context 'with double check' do
      it 'returns true when king is attacked by rook and bishop simultaneously' do
        board = fill_board(
          [
            [Piece[:black, :rook], Square[:e, 8]],
            [Piece[:black, :bishop], Square[:h, 4]],
            [Piece[:black, :king], Square[:d, 8]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )

        position = Position.start.with(board: board, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)
        expect(state.query).to be_in_check(:white)
      end
    end

    context 'with discovered check' do
      it 'returns true when moving a blocking piece reveals a rook attack' do
        # Start with rook blocked
        board = fill_board(
          [
            [Piece[:black, :rook], Square[:e, 8]],
            [Piece[:white, :bishop], Square[:e, 4]],
            [Piece[:black, :king], Square[:d, 8]],
            [Piece[:white, :king], Square[:e, 1]]
          ]
        )
        position = Position.start.with(board: board, castling_rights: CastlingRights.none)
        state = GameState.new(position: position)

        # Move the blocking pawn away
        event = MovePieceEvent[Piece[:white, :bishop], Square[:e, 4], Square[:d, 5]]
        filler_event = MovePieceEvent[Piece[:black, :rook], Square[:e, 8], Square[:e, 7]]
        new_state = state.apply_event(event).apply_event(filler_event)

        expect(new_state.query).to be_in_check(:white)
      end
    end
  end

  describe '#in_checkmate?' do
    it 'returns false when the king is not in check' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :king], Square[:f, 6]]
        ]
      )

      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).not_to be_in_checkmate
    end

    it "Detects checkmate based on move sequence (fool's mate)" do
      event_history = [
        MovePieceEvent[Piece[:white, :pawn], Square[:f, 2], Square[:f, 3]],
        MovePieceEvent[Piece[:black, :pawn], Square[:e, 7], Square[:e, 6]],
        MovePieceEvent[Piece[:white, :pawn], Square[:g, 2], Square[:g, 4]],
        MovePieceEvent[Piece[:black, :queen], Square[:d, 8], Square[:h, 4]]
      ]

      state = event_history.reduce(GameState.new(
                                     position: Position.start.with(castling_rights: CastlingRights.none)
                                   )) do |state, event|
        state.apply_event(event)
      end

      expect(state.query).to be_in_checkmate
    end

    it 'returns true when the current player is checkmated' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :queen], Square[:g, 7]],
          [Piece[:white, :king], Square[:f, 6]]
        ]
      )

      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).to be_in_checkmate
    end

    it 'returns false when the current player is not checkmated' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :queen], Square[:g, 7]],
          [Piece[:white, :king], Square[:f, 6]]
        ]
      )

      position = Position.start.with(board: board, current_color: :white, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).not_to be_in_checkmate
    end

    it 'detects checkmate in double check correctly' do
      board = fill_board(
        [
          [Piece[:black, :king],  Square[:h, 8]],
          [Piece[:white, :rook],  Square[:h, 1]],
          [Piece[:white, :queen], Square[:f, 6]],
          [Piece[:white, :knight], Square[:e, 7]],
          [Piece[:white, :king], Square[:f, 2]]
        ]
      )

      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).to be_in_checkmate
    end

    it 'detects checkmate when the only potential block is illegal due to pin' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:e, 8]],
          [Piece[:black, :rook],  Square[:e, 7]],
          [Piece[:white, :rook],  Square[:e, 1]],
          [Piece[:white, :rook], Square[:f, 2]],
          [Piece[:white, :bishop], Square[:c, 6]],
          [Piece[:white, :knight], Square[:b, 7]],
          [Piece[:white, :king], Square[:h, 1]]
        ]
      )

      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).to be_in_checkmate
    end

    it 'returns false when a legal block is available' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :queen], Square[:g, 7]],
          [Piece[:white, :king], Square[:f, 6]],
          [Piece[:black, :bishop], Square[:f, 8]] # can block queen
        ]
      )
      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).not_to be_in_checkmate
    end

    it 'returns false when the king has a legal move' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :queen], Square[:h, 6]],
          [Piece[:white, :king], Square[:f, 6]]
        ]
      )
      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).not_to be_in_checkmate
    end

    it 'returns false when the king is in stalemate' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:black, :rook], Square[:b, 6]],
          [Piece[:white, :king], Square[:a, 1]],
          [Piece[:white, :pawn], Square[:a, 2]],
          [Piece[:white, :knight], Square[:b, 1]]
        ]
      )
      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).not_to be_in_checkmate
    end

    context 'for special moves - castling, promotion, enpassant' do
      it 'returns false when castling is available' do
        board = fill_board [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:black, :queen], Square[:c, 2]],
          [Piece[:black, :rook], Square[:a, 7]],
          [Piece[:white, :king], Square[:e, 1]],
          [Piece[:white, :rook], Square[:h, 1]]
        ]
        position = Position.start.with(board: board, castling_rights: CastlingRights[
          CastlingSides[true, false],
          CastlingSides.none
        ])
        query = GameQuery.new(position)

        expect(query).not_to be_in_checkmate
      end

      it 'returns false when block by promotion is available' do
        board = fill_board [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:black, :queen], Square[:g, 8]],
          [Piece[:black, :rook], Square[:g, 7]],
          [Piece[:white, :king], Square[:a, 8]],
          [Piece[:white, :pawn], Square[:b, 7]]
        ]

        position = Position.start.with(board: board, castling_rights:
                                       CastlingRights[CastlingSides[true, false], CastlingSides.none])
        query = GameQuery.new(position)

        expect(query).not_to be_in_checkmate
      end

      it 'returns true when checkmate is delivered via promotion' do
        board = fill_board [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :king], Square[:f, 7]],
          [Piece[:white, :pawn], Square[:g, 7]]
        ]
        position = Position.start.with(board: board, current_color: :white, castling_rights: CastlingRights.none)
        query = GameQuery.new(position)

        state_after_promo = query.state.apply_event(
          MovePieceEvent[Piece[:white, :pawn], Square[:g, 7], Square[:g, 8]]
          .promote(:queen)
        )

        expect(state_after_promo.query).to be_in_checkmate
      end

      it 'returns false when en passant can block a checkmate' do
        board = fill_board(
          [
            [Piece[:black, :king], Square[:f, 6]],
            [Piece[:black, :knight], Square[:f, 4]],
            [Piece[:black, :rook], Square[:b, 3]],
            [Piece[:black, :pawn], Square[:g, 5]], # moved last
            [Piece[:white, :pawn], Square[:f, 5]],
            [Piece[:white, :pawn], Square[:g, 4]],
            [Piece[:white, :king], Square[:h, 4]]
          ]
        )
        position = Position.start.with(
          board: board,
          castling_rights: CastlingRights.none,
          en_passant_target: Square[:g, 6]
        )
        query = GameQuery.new(position)

        expect(query).not_to be_in_checkmate
      end

      it 'returns false when black can capture en passant to escape mate' do
        board = fill_board(
          [
            [Piece[:black, :king],  Square[:a, 5]],
            [Piece[:black, :pawn],  Square[:a, 6]],
            [Piece[:black, :pawn],  Square[:b, 6]],
            [Piece[:black, :pawn],  Square[:b, 5]],
            [Piece[:black, :pawn],  Square[:a, 4]],  # can capture en passant to b3
            [Piece[:white, :pawn],  Square[:b, 4]],  # just moved b2-b4, checking a5
            [Piece[:white, :knight], Square[:d, 3]],
            [Piece[:white, :king],  Square[:h, 1]]
          ]
        )

        position = Position.start.with(
          board: board,
          current_color: :black,
          castling_rights: CastlingRights.none,
          en_passant_target: Square[:b, 3] # square passed over by b2-b4
        )
        query = GameQuery.new(position)

        expect(query).to be_in_check
        expect(query).not_to be_in_checkmate
      end

      it 'returns true when en passant target is missing (no escape)' do
        board = fill_board(
          [
            [Piece[:black, :king],  Square[:a, 5]],
            [Piece[:black, :pawn],  Square[:a, 6]],
            [Piece[:black, :pawn],  Square[:b, 6]],
            [Piece[:black, :pawn],  Square[:b, 5]],
            [Piece[:black, :pawn],  Square[:a, 4]],  # would-be en passant capturer
            [Piece[:white, :pawn],  Square[:b, 4]],  # pawn on b4 checking a5
            [Piece[:white, :knight], Square[:d, 3]],
            [Piece[:white, :king], Square[:h, 1]]
          ]
        )

        position = Position.start.with(
          board: board,
          current_color: :black,
          castling_rights: CastlingRights.none,
          en_passant_target: nil
        )

        query = GameQuery.new(position)

        expect(query).to be_in_check
        expect(query).to be_in_checkmate
      end
    end
  end

  describe '#stalemate?' do
    it 'returns false when the king can move' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :king], Square[:f, 6]]
        ]
      )
      position = Position.start.with(board: board, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).not_to be_stalemate
    end

    it 'returns false when the king is in checkmate' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:white, :queen], Square[:g, 7]],
          [Piece[:white, :king], Square[:f, 6]]
        ]
      )

      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).not_to be_stalemate
    end

    it 'returns false when king cannot move but a pawn can' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:h, 8]],
          [Piece[:black, :pawn], Square[:a, 7]],
          [Piece[:white, :queen], Square[:g, 6]],
          [Piece[:white, :king], Square[:f, 6]]
        ]
      )

      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)
      expect(query).not_to be_stalemate
    end

    it 'returns true for stalemate (black)' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:a, 8]],
          [Piece[:white, :king], Square[:c, 1]],
          [Piece[:white, :queen], Square[:c, 7]]

        ]
      )
      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).to be_stalemate
    end

    it 'returns true for stalemate (white)' do
      board = fill_board(
        [
          [Piece[:white, :king], Square[:a, 8]],
          [Piece[:black, :king], Square[:c, 1]],
          [Piece[:black, :queen], Square[:c, 7]]

        ]
      )
      position = Position.start.with(board: board, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).to be_stalemate
    end

    it 'returns true for more complex stalemate (white)' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:g, 8]],
          [Piece[:black, :bishop], Square[:a, 7]],
          [Piece[:black, :pawn], Square[:f, 4]],
          [Piece[:black, :pawn], Square[:h, 3]],
          [Piece[:white, :king], Square[:h, 1]],
          [Piece[:white, :pawn], Square[:h, 2]]
        ]
      )
      position = Position.start.with(board: board, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).to be_stalemate
    end

    it 'returns true for more complex stalemate (black)' do
      board = fill_board(
        [
          [Piece[:black, :king], Square[:a, 3]],
          [Piece[:black, :pawn], Square[:a, 4]],
          [Piece[:white, :king], Square[:b, 1]],
          [Piece[:white, :rook], Square[:b, 8]],
          [Piece[:white, :rook], Square[:d, 4]]
        ]
      )
      position = Position.start.with(board: board, current_color: :black, castling_rights: CastlingRights.none)
      query = GameQuery.new(position)

      expect(query).to be_stalemate
    end
  end

  describe '#insufficient_material?' do
    def query_for(pieces)
      board = fill_board(pieces)
      GameQuery.new(Position.start.with(castling_rights: CastlingRights.none, board: board))
    end

    it 'returns true for king vs king' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:black, :king], Square[:e, 8]]
                        ])
      expect(query).to be_insufficient_material
    end

    it 'returns true for king and bishop vs king' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:white, :bishop], Square[:c, 1]],
                          [Piece[:black, :king], Square[:e, 8]]
                        ])
      expect(query).to be_insufficient_material
    end

    it 'returns true for king and knight vs king' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:white, :knight], Square[:g, 1]],
                          [Piece[:black, :king], Square[:e, 8]]
                        ])
      expect(query).to be_insufficient_material
    end

    it 'returns true for king vs king and bishop (color swapped)' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:black, :king], Square[:e, 8]],
                          [Piece[:black, :bishop], Square[:c, 8]]
                        ])
      expect(query).to be_insufficient_material
    end

    it 'returns true for both sides having bishops on same color squares' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:black, :king], Square[:e, 8]],
                          [Piece[:white, :bishop], Square[:c, 1]], # dark square
                          [Piece[:black, :bishop], Square[:a, 3]]  # dark square
                        ])
      expect(query).to be_insufficient_material
    end

    it 'returns false for both sides having bishops on opposite colors' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:black, :king], Square[:e, 8]],
                          [Piece[:white, :bishop], Square[:c, 1]], # dark square
                          [Piece[:black, :bishop], Square[:b, 3]]  # light square
                        ])
      expect(query).not_to be_insufficient_material
    end

    it 'returns false when a pawn is present' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:white, :pawn], Square[:d, 4]],
                          [Piece[:black, :king], Square[:e, 8]]
                        ])
      expect(query).not_to be_insufficient_material
    end

    it 'returns false when a rook is present' do
      query = query_for([
                          [Piece[:white, :king], Square[:e, 1]],
                          [Piece[:black, :king], Square[:e, 8]],
                          [Piece[:black, :rook], Square[:a, 8]]
                        ])
      expect(query).not_to be_insufficient_material
    end
  end

  describe '#fifty_move_rule?' do
    it 'returns true when halfmove clock reaches 100' do
      position = Position.start.with(castling_rights: CastlingRights.none, halfmove_clock: 100)
      query = GameQuery.new(position)

      expect(query.fifty_move_rule?).to be true
    end

    it 'returns false when halfmove clock is below 100' do
      position = Position.start.with(castling_rights: CastlingRights.none, halfmove_clock: 99)
      query = GameQuery.new(position)
      expect(query.fifty_move_rule?).to be false
    end
  end

  describe '#threefold_repetition?' do
    let(:position) do
      Position.start.with(board: fill_board(
        [
          [Piece[:black, :king], Square[:e, 8]],
          [Piece[:black, :rook], Square[:e, 7]],
          [Piece[:white, :rook], Square[:f, 2]],
          [Piece[:white, :bishop], Square[:c, 6]],
          [Piece[:white, :knight], Square[:b, 7]],
          [Piece[:white, :king], Square[:h, 1]]
        ]
      ))
    end

    it 'returns true for the current square being repeated 3 times' do
      position_signatures = Immutable::Hash[position.signature => 3, Position.start.signature => 1]
      query = GameQuery.new(position, GameHistory.start.with(position_signatures: position_signatures))
      expect(query).to be_threefold_repetition
    end

    it 'returns false for the current position being repeated less than 3 times' do
      position_signatures = Immutable::Hash[position.signature => 2, Position.start.signature => 1]
      query = GameQuery.new(position, GameHistory.start.with(position_signatures: position_signatures))
      expect(query).not_to be_threefold_repetition
    end

    it 'returns false for the previous position being repeated 3 or more times' do
      position_signatures = Immutable::Hash[position.signature => 4, Position.start.signature => 1]
      current_position = Position.start.with(board: fill_board(
        [
          [Piece[:white, :king], Square[:e, 1]],
          [Piece[:black, :king], Square[:e, 8]],
          [Piece[:black, :rook], Square[:a, 8]]
        ]
      ))
      query = GameQuery.new(current_position, GameHistory.start.with(position_signatures: position_signatures))
      expect(query).not_to be_threefold_repetition
    end
  end
end
