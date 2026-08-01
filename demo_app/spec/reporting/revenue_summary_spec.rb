# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reporting::RevenueSummary do
  it "sums the amount of the user's invoices" do
    user = Accounts::User.create!(name: "Ada", email: "ada@example.com")
    Billing::Invoice.create!(user_id: user.id, amount_cents: 300, status: "pending")
    Billing::Invoice.create!(user_id: user.id, amount_cents: 700, status: "pending")
    invoice = Billing::Invoice.new(user_id: user.id)

    expect(described_class.new.record(invoice)).to eq(1000)
  end
end
