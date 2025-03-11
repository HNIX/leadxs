class LeadPolicy < ApplicationPolicy
  # Note: We're inheriting initialize from ApplicationPolicy,
  # which sets up @account_user and @record
  
  def index?
    # Allow access if the user is a member of the account this lead belongs to
    account_user.present?
  end
  
  def show?
    # Same policy as index
    account_user.present?
  end
  
  class Scope < Scope
    def resolve
      # Only show leads from the current account
      scope.where(account: account_user.account)
    end
  end
end