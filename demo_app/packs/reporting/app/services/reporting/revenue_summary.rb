# frozen_string_literal: true

module Reporting
  # Aggregates revenue for a user. Depends on Accounts and Billing, both of
  # which Reporting properly declares - these are valid cross-package
  # dependencies. (Billing referencing Reporting back is what creates the cycle.)
  class RevenueSummary
    def self.record(invoice)
      new.record(invoice)
    end

    def record(invoice)
      user = Accounts::User.find(invoice.user_id)
      total = Billing::Invoice.where(user_id: user.id).sum(:amount_cents)
      Rails.logger.info("User #{user.id} revenue: #{total} cents")
      total
    end
  end
end
