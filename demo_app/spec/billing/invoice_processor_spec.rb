# frozen_string_literal: true

require "rails_helper"

RSpec.describe Billing::InvoiceProcessor do
  include ActiveJob::TestHelper

  let(:user) { Accounts::User.create!(name: "Ada", email: "ada@example.com") }
  let(:invoice) do
    Billing::Invoice.create!(user_id: user.id, amount_cents: 500, status: "pending")
  end

  it "marks the invoice as processed" do
    perform_enqueued_jobs do
      described_class.new.call(invoice)
    end

    expect(invoice.reload.status).to eq("processed")
  end

  it "enqueues a receipt notification for the user (the hidden runtime dependency)" do
    expect { described_class.new.call(invoice) }
      .to have_enqueued_job(Notifications::ReceiptJob).with(user.id)
  end
end
