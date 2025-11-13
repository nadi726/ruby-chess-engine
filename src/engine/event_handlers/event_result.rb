# frozen_string_literal: true

# Represents the outcome of processing a chess event.
#
# - On success: contains the finalized event, and `error` is nil.
# - On failure: contains an error message (`error`), and `event` is nil.
EventResult = Data.define(:event, :error) do
  def success? = error.nil?
  def failure? = !success?

  def self.success(event) = new(event, nil)
  def self.failure(error) = new(nil, error)

  private_class_method :new # enforces use of factories
end
