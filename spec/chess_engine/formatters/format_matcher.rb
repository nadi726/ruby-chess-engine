# frozen_string_literal: true

RSpec::Matchers.define :format do |event|
  chain :and_return do |expected_str|
    @expected_str = expected_str
  end

  match do |formatter|
    @actual_str = formatter.call(event)
    if @expected_str
      values_match?(@actual_str, @expected_str)
    else
      !@actual_str.nil?
    end
  end

  failure_message do |formatter|
    if @expected_str
      "expected #{formatter} to format event #{event.inspect} as:\n  #{@expected_str.inspect}\nbut got:\n  #{@actual_str.inspect}"
    else
      "expected #{formatter} to format event #{event.inspect}, but it returned nil"
    end
  end

  failure_message_when_negated do |formatter|
    "expected #{formatter} not to format event #{event.inspect}, but it returned:\n  #{@actual_str.inspect}"
  end
end
