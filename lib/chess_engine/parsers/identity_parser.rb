# frozen_string_literal: true

require_relative '../data_definitions/events'

module ChessEngine
  module Parsers
    # A parser that returns the input event unchanged.
    # Used primarily for testing, as it bypasses actual notation parsing
    # and assumes the input is already valid.
    class IdentityParser
      def self.call(notation, _game_query)
        return nil unless notation.is_a?(Events::BaseEvent)

        notation
      end
    end
  end
end
