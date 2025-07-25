# frozen_string_literal: true

# Represents the outcome of processing a chess event sequence.
#
# - On success: contains the finalized list of events (`events`), and `error` is nil.
# - On failure: contains an error message (`error`), and `events` is nil.
#
# Note: The `error` field is currently a string, but may be replaced
#       with a structured error object in the future to support programmatic handling.
EventResult = Data.define(:events, :error) do
  def success? = error.nil?
  def failure? = !success?

  def self.success(events) = new(events, nil)
  def self.failure(error)  = new(nil, error)

  private_class_method :new # enforces use of factories
end
