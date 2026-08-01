# frozen_string_literal: true

module Notifications
  # Background job that "sends" a receipt to a user. Depends on Accounts::User,
  # which is a valid declared dependency (notifications -> accounts).
  #
  # This job is enqueued by Billing at runtime via a string, so nothing
  # statically links Billing to it - that is the hidden runtime dependency.
  class ReceiptJob < ApplicationJob
    def perform(user_id)
      user = Accounts::User.find(user_id)
      Rails.logger.info("Receipt sent to #{user.email}")
    end
  end
end
