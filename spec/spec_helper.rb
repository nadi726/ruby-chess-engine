# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'debug'
require 'chess_engine_rb'
require_relative 'support/helpers'
require_relative 'support/shared_state'

# Autoload all `ChessEngine` constants, so that tests will not be too verbose
def Object.const_missing(name)
  if ChessEngine.const_defined?(name)
    ChessEngine.const_get(name)
  else
    super
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.include StartState
end
