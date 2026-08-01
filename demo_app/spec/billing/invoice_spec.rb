# frozen_string_literal: true

require "rails_helper"

RSpec.describe Billing::Invoice do
  it "rejects a negative amount" do
    invoice = described_class.new(amount_cents: -1)

    expect(invoice).not_to be_valid
  end

  it "accepts a non-negative amount" do
    invoice = described_class.new(amount_cents: 500)

    expect(invoice).to be_valid
  end
end
