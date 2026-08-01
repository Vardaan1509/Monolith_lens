# frozen_string_literal: true

module Notifications
  # Sends an alert about an invoice. It reaches into Billing::Invoice even
  # though the Notifications package does NOT declare a dependency on Billing.
  #
  # This is the intentional STATIC BOUNDARY VIOLATION: a plain constant
  # reference that crosses a package boundary without being declared. Both
  # Packwerk and MonolithLens will flag it.
  class InvoiceAlert
    def call(invoice_id)
      invoice = Billing::Invoice.find(invoice_id)
      Rails.logger.info("Alert: invoice #{invoice.id} is #{invoice.status}")
    end
  end
end
