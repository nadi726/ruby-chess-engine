# frozen_string_literal: true

require_relative 'board'

# Tracks whether each side still retains castling rights.
# Rights may be lost due to moving the king or rook, or other game events.
CastlingRights = Data.define(
  :white_kingside, :white_queenside,
  :black_kingside, :black_queenside
)

# Immutable container for the current turn's game data:
# board layout, active color, en passant target, castling rights, and halfmove clock.
# Used by GameState as the core snapshot of the position.
GameData = Data.define(
  :board,
  :current_color,
  :en_passant_target,
  :castling_rights,
  :halfmove_clock
) do
  def self.start
    GameData[
      board: Board.start,
      current_color: :white,
      en_passant_target: nil,
      castling_rights: CastlingRights.new(
        white_kingside: true, white_queenside: true,
        black_kingside: true, black_queenside: true
      ),
      halfmove_clock: 0
    ]
  end

  def position_signature
    [
      board.pieces_with_positions,
      current_color,
      en_passant_target,
      castling_rights
    ].hash
  end
end
