require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  attr_accessor :controller_name, :action_name

  test 'authentication_page? returns true for sessions controller' do
    @controller_name = 'sessions'
    @action_name = 'new'

    assert authentication_page?

    @action_name = 'create'

    assert authentication_page?

    @action_name = 'destroy'

    assert authentication_page?
  end

  test 'authentication_page? returns true for users#new' do
    @controller_name = 'users'
    @action_name = 'new'

    assert authentication_page?
  end

  test 'authentication_page? returns false for users#edit' do
    @controller_name = 'users'
    @action_name = 'edit'

    assert_not authentication_page?
  end

  test 'authentication_page? returns true for passwords#new' do
    @controller_name = 'passwords'
    @action_name = 'new'

    assert authentication_page?
  end

  test 'authentication_page? returns true for passwords#edit' do
    @controller_name = 'passwords'
    @action_name = 'edit'

    assert authentication_page?
  end

  test 'authentication_page? returns false for passwords#update' do
    @controller_name = 'passwords'
    @action_name = 'update'

    assert_not authentication_page?
  end

  test 'authentication_page? returns false for other controllers' do
    @controller_name = 'transactions'
    @action_name = 'index'

    assert_not authentication_page?

    @controller_name = 'home'
    @action_name = 'index'

    assert_not authentication_page?
  end

  test 'gravatar_url generates correct URL with default size' do
    email = 'test@example.com'
    expected_hash = Digest::MD5.hexdigest(email)
    url = gravatar_url(email)

    assert_equal "https://www.gravatar.com/avatar/#{expected_hash}?s=80&d=mp", url
  end

  test 'gravatar_url generates correct URL with custom size' do
    email = 'test@example.com'
    expected_hash = Digest::MD5.hexdigest(email)
    url = gravatar_url(email, size: 200)

    assert_equal "https://www.gravatar.com/avatar/#{expected_hash}?s=200&d=mp", url
  end

  test 'gravatar_url downcases email before hashing' do
    lowercase_hash = Digest::MD5.hexdigest('test@example.com')
    url = gravatar_url('TEST@EXAMPLE.COM')

    assert_includes url, lowercase_hash
  end

  test 'gravatar_url strips whitespace from email' do
    stripped_hash = Digest::MD5.hexdigest('test@example.com')
    url = gravatar_url('  test@example.com  ')

    assert_includes url, stripped_hash
  end

  test 'gravatar_url handles nil email' do
    expected_hash = Digest::MD5.hexdigest('')
    url = gravatar_url(nil)

    assert_equal "https://www.gravatar.com/avatar/#{expected_hash}?s=80&d=mp", url
  end

  test 'pull_to_refresh? returns true for transactions#index' do
    @controller_name = 'transactions'
    @action_name = 'index'

    assert pull_to_refresh?
  end

  test 'pull_to_refresh? returns false for transactions#show' do
    @controller_name = 'transactions'
    @action_name = 'show'

    assert_not pull_to_refresh?
  end

  test 'pull_to_refresh? returns false for other controllers' do
    @controller_name = 'profiles'
    @action_name = 'show'

    assert_not pull_to_refresh?
  end

  test 'pull_to_refresh_pages returns array of whitelisted pages' do
    assert_includes pull_to_refresh_pages, 'transactions#index'
  end
end
