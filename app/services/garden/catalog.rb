# frozen_string_literal: true
# typed: false

module Garden
  # Reads the shipped curated data (db/garden/*.yml) that Perenual doesn't
  # provide: the sowing/harvest calendar and companion-planting table. Pure
  # lookup, memoized at the class level -- the files never change at runtime.
  #
  # Crop matching is by normalized name (transliterated + downcased), so a
  # plant called "Tomate" or "Cherry Tomato" both resolve to the `tomato` entry
  # via its aliases.
  module Catalog
    DATA_DIR = Rails.root.join("db/garden")

    Sowing = Struct.new(:key, :sow_from, :sow_to, :harvest_from, :harvest_to, keyword_init: true)

    class << self
      # Look up the sowing entry for a plant name.
      # @param name [String]
      # @return [Sowing, nil]
      def sowing_for(name)
        key = match_key(name)
        key && sowing_by_key[key]
      end

      # Resolve the canonical crop key for a plant name (nil if uncatalogued).
      # @param name [String]
      # @return [String, nil]
      def crop_key_for(name)
        match_key(name)
      end

      # Companion planting for a crop key.
      # @param crop_key [String, nil]
      # @return [Hash{Symbol=>Array<String>}] { good: [...], bad: [...] }
      def companions(crop_key)
        companions_by_key.fetch(crop_key, { good: [], bad: [] })
      end

      # @return [String] transliterated, downcased, squished match key.
      def normalize(value)
        I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
      end

      def reset_cache!
        @sowing_by_key = @companions_by_key = @alias_index = nil
      end

      private

      # Match a free-text name to a crop key: exact alias hit first, else the
      # longest alias that appears as a whole word in the name (so "Cherry
      # Tomato" -> tomato).
      def match_key(name)
        norm = normalize(name)
        return nil if norm.blank?
        return alias_index[norm] if alias_index.key?(norm)

        words = norm.split
        alias_index
          .select { |ali, _| ali.split.all? { |w| words.include?(w) } }
          .max_by { |ali, _| ali.length }
          &.last
      end

      def sowing_by_key
        @sowing_by_key ||= load_yaml("sowing_calendar.yml").fetch("crops", []).to_h do |c|
          [c["key"], Sowing.new(key: c["key"],
                                sow_from: c.dig("sow", 0), sow_to: c.dig("sow", 1),
                                harvest_from: c.dig("harvest", 0), harvest_to: c.dig("harvest", 1))]
        end
      end

      def companions_by_key
        @companions_by_key ||= load_yaml("companions.yml").fetch("crops", {}).transform_values do |v|
          { good: Array(v["good"]).map(&:to_s), bad: Array(v["bad"]).map(&:to_s) }
        end
      end

      # Reverse index: every normalized alias -> crop key.
      def alias_index
        @alias_index ||= load_yaml("sowing_calendar.yml").fetch("crops", []).each_with_object({}) do |c, idx|
          Array(c["names"]).each { |n| idx[normalize(n)] = c["key"] }
          idx[normalize(c["key"])] = c["key"]
        end
      end

      def load_yaml(file)
        YAML.safe_load_file(DATA_DIR.join(file)) || {}
      end
    end
  end
end
