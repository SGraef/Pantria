# frozen_string_literal: true
# typed: false

# A household's binding to the Perenual plant API (perenual.com): an API key
# used to search the species catalog and read care data, plus the local growing
# context (hardiness zone / region) that tailors the sowing calendar.
#
# The key is encrypted at rest via Active Record encryption (keys derived from
# SECRET_KEY_BASE -- see config/initializers/active_record_encryption.rb).
#
# The whole garden feature is optional and degrades gracefully: with no
# connection (or no key) the catalog can still hold hand-added plants and the
# planner works -- only the Perenual search is unavailable. See {Plant}.
class GardenConnection < ApplicationRecord
  belongs_to :household

  encrypts :api_key

  # Central-Europe default (Homestead is German-first). Users in other regions
  # override it in the connection settings; it only shifts the sowing calendar.
  DEFAULT_HARDINESS_ZONE = "7"

  # @return [Boolean] true once we have a key to reach Perenual with.
  def connected?
    api_key.present?
  end

  # @return [String] the effective hardiness zone (falls back to the default).
  def effective_zone
    hardiness_zone.presence || DEFAULT_HARDINESS_ZONE
  end
end
