class ApplicationController < ActionController::Base
  include Authentication

  before_action :set_paper_trail_whodunnit

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def user_for_paper_trail
    Current.user&.id
  end
end
