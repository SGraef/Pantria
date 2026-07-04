# frozen_string_literal: true
# typed: false

module Perenual
  # Free-tier quota exhausted (HTTP 429).
  class RateLimitError < Error; end
end
