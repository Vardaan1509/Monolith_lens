# frozen_string_literal: true

module Billing
  # Processes an invoice. This one service object deliberately exercises three
  # different kinds of cross-package dependency:
  #
  # 1. Accounts::User  - a VALID, declared dependency (billing -> accounts).
  # 2. Reporting::RevenueSummary - an UNDECLARED reference (billing does not
  #    declare reporting). Because reporting declares billing, this closes a
  #    dependency CYCLE. Packwerk reports it only as an undeclared reference;
  #    MonolithLens will surface it as a cycle.
  # 3. Notifications::ReceiptJob - enqueued dynamically via a STRING, so there
  #    is no static constant reference. Static analysis and Packwerk cannot see
  #    it; only runtime tracing will. This is the "hidden runtime dependency".
  class InvoiceProcessor
    def call(invoice)
      user = Accounts::User.find(invoice.user_id)

      Reporting::RevenueSummary.record(invoice)
      enqueue_receipt(user)

      invoice.update!(status: "processed")
    end

    private

    def enqueue_receipt(user)
      "Notifications::ReceiptJob".constantize.perform_later(user.id)
    end
  end
end
