# frozen_string_literal: true
# typed: false

module Perenual
  # Missing / rejected API key (HTTP 401/403).
  class AuthError < Error; end
end
