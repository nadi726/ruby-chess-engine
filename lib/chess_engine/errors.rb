# frozen_string_literal: true

module ChessEngine
  # Those are errors that should be used internally by `Engine` and its components when something goes wrong.
  #
  # Not to be confused with errors that are expected as part of engine-client interaction,
  # which are a regular part of the control flow, and returned to the listeners in the form of `GameUpdate.error`.
  module Errors
    # A base class for the specific invariant violations below.
    # Signifies that an invariant inside of one of the engine's components, such as `Game::State`, has been violated.
    class InvariantViolationError < StandardError; end

    # Raised when `Game::State` receives an invalid event.
    class InvalidEventError < InvariantViolationError; end

    # Raised when attempting illegal manipulations on the `Board`.
    # (e.g., removing a piece from an empty square)
    class BoardManipulationError < InvariantViolationError; end

    # Raised when attempting to use an invalid `Square`.
    # Note that squares can be created invalidly by design, but using them is forbidden.
    class InvalidSquareError < InvariantViolationError; end

    # Signals to the client that the engine malfunctioned internally.
    # While the other errors are used inside the engine for communication,
    # this is the single error that clients should see.
    class InternalError < StandardError; end
  end

  InvariantViolationError = Errors::InvariantViolationError
  InvalidEventError = Errors::InvalidEventError
  BoardManipulationError = Errors::BoardManipulationError
  InvalidSquareError = Errors::InvalidSquareError
  InternalEngineError = Errors::InternalError
end
