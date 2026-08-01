# frozen_string_literal: true

require "rails_helper"

RSpec.describe Accounts::User do
  it "normalizes the email before validation" do
    user = described_class.create!(name: "Ada", email: "  Ada@Example.COM ")

    expect(user.email).to eq("ada@example.com")
  end

  it "requires an email" do
    user = described_class.new(name: "Ada", email: "")

    expect(user).not_to be_valid
  end
end
