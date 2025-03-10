# frozen_string_literal: true

class CompliancePolicy < ApplicationPolicy
  # Regular compliance access for viewing records and history
  def access?
    account_user.admin? || account_user.member?
  end

  # Regulatory access is more restricted, for generating official reports
  def regulatory_access?
    account_user.admin?
  end
end