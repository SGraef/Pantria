# frozen_string_literal: true
# typed: false

# Named color palette for user-managed labels (project statuses and
# categories). Deliberately NOT free hex input: each name maps to a
# `.chip-color-<name>` CSS class built on the theme's soft color variables,
# so chips stay legible in both light and dark themes.
module ColorPalette
  extend ActiveSupport::Concern

  COLORS = %w[clay olive moss sand terracotta sky].freeze

  included do
    validates :color, inclusion: { in: COLORS }, allow_blank: true
  end
end
