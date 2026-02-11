module ApplicationHelper
  def authentication_page?
    controller_name == 'sessions' ||
      (controller_name == 'users' && action_name == 'new') ||
      (controller_name == 'passwords' && action_name.in?(%w[new edit]))
  end

  def gravatar_url(email_address, size: 80)
    hash = Digest::MD5.hexdigest(email_address.to_s.downcase.strip)

    "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=mp"
  end

  def pull_to_refresh?
    pull_to_refresh_pages.include?("#{controller_name}##{action_name}")
  end

  def swipe_nav?
    swipe_nav_pages.include?(controller_name)
  end

  def swipe_nav_paths
    %w[/transactions /expenses /goals]
  end

  def swipe_nav_current_index
    swipe_nav_pages.index(controller_name) || 0
  end

  private

  def pull_to_refresh_pages
    %w[
      transactions#index
    ]
  end

  def swipe_nav_pages
    %w[transactions expenses goals]
  end
end
