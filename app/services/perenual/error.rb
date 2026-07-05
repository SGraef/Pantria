# frozen_string_literal: true
# typed: false

module Perenual
  # Base error for any Perenual API failure surfaced to the user. {AuthError}
  # (401/403) and {RateLimitError} (429) are subclasses.
  class Error < StandardError; end
end
