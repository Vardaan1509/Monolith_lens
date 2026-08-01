# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::InvoiceAlert do
  it "looks up the invoice by id without error" do
    user = Accounts::User.create!(name: "Ada", email: "ada@example.com")
    invoice = Billing::Invoice.create!(user_id: user.id, amount_cents: 100, status: "pending")

    expect { described_class.new.call(invoice.id) }.not_to raise_error
  end
end
