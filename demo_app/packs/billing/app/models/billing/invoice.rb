# frozen_string_literal: true

module Billing
  # An invoice belonging to a user. Stores an amount (in cents) and a status.
  class Invoice < ApplicationRecord
    STATUSES = %w[pending processed].freeze

    validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  end
end
