# frozen_string_literal: true

require 'pathname'
lib_dir = Pathname.new(__FILE__).dirname.expand_path

$LOAD_PATH.unshift(lib_dir.to_s) unless $LOAD_PATH.include?(lib_dir.to_s)

# Main namespace for the engine.
# Contains all core logic, data definitions, parsers, and more.
module ChessEngine
  # --- Main components ---
  # Main class
  autoload :Engine, 'chess_engine/engine'

  # components
  autoload :EventHandlers, 'chess_engine/event_handlers/init'
  autoload :Game, 'chess_engine/game/init'
  autoload :Parsers, 'chess_engine/parsers/init'
  autoload :Formatters, 'chess_engine/formatters/init'

  # --- Data Definitions ---
  autoload :Piece, 'chess_engine/data_definitions/piece'
  autoload :Square, 'chess_engine/data_definitions/square'
  autoload :Board, 'chess_engine/data_definitions/board'

  autoload :Position, 'chess_engine/data_definitions/position'
  autoload :CastlingRights, 'chess_engine/data_definitions/components/castling_rights'

  # Events
  autoload :Events, 'chess_engine/data_definitions/events'
  autoload :MovePieceEvent, 'chess_engine/data_definitions/events'
  autoload :CastlingEvent, 'chess_engine/data_definitions/events'
  autoload :EnPassantEvent, 'chess_engine/data_definitions/events'

  # primitive data definitions
  autoload :CastlingData, 'chess_engine/data_definitions/primitives/castling_data'
  autoload :Colors, 'chess_engine/data_definitions/primitives/colors'
  autoload :CoreNotation, 'chess_engine/data_definitions/primitives/core_notation'

  # --- Errors ---
  autoload :InvariantViolationError, 'chess_engine/errors'
  autoload :InvalidEventError, 'chess_engine/errors'
  autoload :BoardManipulationError, 'chess_engine/errors'
  autoload :InvalidSquareError, 'chess_engine/errors'
  autoload :InternalEngineError, 'chess_engine/errors'
end
