class ApplicationController < ActionController::Base
  set_referral_cookie
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  include Accounts::SubscriptionStatus
  include ActiveStorage::SetCurrent
  include Authentication
  include Authorization
  include DeviceFormat
  include Pagy::Backend
  include SetCurrentRequestDetails
  include SetLocale
  include Sortable
  include Users::AgreementUpdates
  include Users::NavbarNotifications
  include Users::Sudo
end
