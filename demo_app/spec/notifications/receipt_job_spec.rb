# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::ReceiptJob do
  it "runs for an existing user" do
    user = Accounts::User.create!(name: "Ada", email: "ada@example.com")

    expect { described_class.new.perform(user.id) }.not_to raise_error
  end

  it "raises when the user does not exist" do
    expect { described_class.new.perform(-1) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
