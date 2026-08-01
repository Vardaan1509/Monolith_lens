# frozen_string_literal: true

module Accounts
  # A user of the system. The base domain - depends on nothing else.
  class User < ApplicationRecord
    before_validation :normalize_email

    validates :email, presence: true

    private

    # A callback: runs automatically before the record is validated.
    def normalize_email
      self.email = email.to_s.strip.downcase
    end
  end
end
