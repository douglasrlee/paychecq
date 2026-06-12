class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  before_action :set_paper_trail_whodunnit

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # :nocov:
  def user_for_paper_trail
    Current.user&.id
  end
  # :nocov:

  protected

  # Preserve the pagy 9.x `overflow: :last_page` behavior by clamping
  # an out-of-range page request back to the last available page.
  def pagy(collection, **options)
    pagy, records = super
    return [ pagy, records ] unless pagy.respond_to?(:last) && pagy.page > pagy.last

    super(collection, **options.merge(page: pagy.last))
  end
end
