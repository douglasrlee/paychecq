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
end
