class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # TODO: Add this when I add auth
  # before_action :set_paper_trail_whodunnit
end
