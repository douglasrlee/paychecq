require 'test_helper'

class TransactionNameOverridesControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:johndoe) }

  test 'create requires authentication' do
    post transaction_name_overrides_url, params: { transaction_name_override: { match_type: 'exact', match_text: 'AMAZON', replacement_name: 'Amazon' } }

    assert_redirected_to new_session_path
  end

  test 'create persists the override' do
    sign_in_as(@user)

    assert_difference '@user.transaction_name_overrides.count', 1 do
      post transaction_name_overrides_url,
           params: { transaction_name_override: { match_type: 'exact', match_text: 'AMAZON', replacement_name: 'Amazon' } }
    end

    override = @user.transaction_name_overrides.order(:created_at).last
    assert_equal 'exact', override.match_type
    assert_equal 'AMAZON', override.match_text
    assert_equal 'Amazon', override.replacement_name
  end

  test 'create responds with turbo_stream when requested' do
    sign_in_as(@user)

    post transaction_name_overrides_url,
         params: { transaction_name_override: { match_type: 'exact', match_text: 'AMAZON', replacement_name: 'Amazon' } },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
  end

  test 'create redirects with alert when invalid' do
    sign_in_as(@user)

    assert_no_difference '@user.transaction_name_overrides.count' do
      post transaction_name_overrides_url, params: { transaction_name_override: { match_type: 'exact', match_text: '', replacement_name: 'Amazon' } }
    end

    assert_response :see_other
    assert_match(/can't be blank/, flash[:alert])
  end

  test 'destroy removes the override' do
    sign_in_as(@user)
    override = transaction_name_overrides(:test_exact)

    assert_difference '@user.transaction_name_overrides.count', -1 do
      delete transaction_name_override_url(override),
             headers: { Accept: 'text/vnd.turbo-stream.html' }
    end

    assert_response :success
  end

  test 'destroy with transaction_id includes drawer frame in stream' do
    sign_in_as(@user)
    override = transaction_name_overrides(:test_exact)
    transaction = Transaction.create!(name: 'TESTEXACT', amount: 5.50, bank_account: bank_accounts(:chase_checking))

    delete transaction_name_override_url(override),
           params: { transaction_id: transaction.id },
           headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/drawer_content/, response.body)
  end

  test 'destroy from settings replaces the transaction_name_overrides frame with the current page' do
    sign_in_as(@user)
    @user.transaction_name_overrides.destroy_all
    overrides = 7.times.map { |i| @user.transaction_name_overrides.create!(match_type: 'exact', match_text: "SEED#{i}", replacement_name: "Seeded #{i}") }
    target = overrides.last

    delete transaction_name_override_url(target, page: 2),
           headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="transaction_name_overrides"/, response.body)
    assert_match(/Page 2 of 2/, response.body)
    assert_match(%r{href="/settings\?page=1"}, response.body)
  end

  test 'destroy with missing record returns no_content for turbo_stream' do
    sign_in_as(@user)

    delete transaction_name_override_url('00000000-0000-0000-0000-000000000000'),
           headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :no_content
  end

  test 'destroy with missing record redirects to settings for html' do
    sign_in_as(@user)

    delete transaction_name_override_url('00000000-0000-0000-0000-000000000000')

    assert_redirected_to settings_path
  end

  test 'create with contains match type updates matching transaction rows' do
    sign_in_as(@user)
    matching = Transaction.create!(name: 'a freshmatch transaction', amount: 12.50, bank_account: bank_accounts(:chase_checking))

    post transaction_name_overrides_url,
         params: {
           transaction_name_override: { match_type: 'contains', match_text: 'freshmatch', replacement_name: 'Renamed' },
           transaction_id: matching.id
         },
         headers: { Accept: 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_match(/#{ActionView::RecordIdentifier.dom_id(matching)}/, response.body)
    assert_match(/Renamed/, response.body)
  end

  test 'safe_return_path rejects scheme-relative URLs' do
    sign_in_as(@user)

    post transaction_name_overrides_url,
         params: { transaction_name_override: { match_type: 'exact', match_text: '', replacement_name: '' }, return_to: '//evil.com' }

    assert_redirected_to settings_path
  end

  test 'safe_return_path accepts local paths' do
    sign_in_as(@user)

    post transaction_name_overrides_url,
         params: { transaction_name_override: { match_type: 'exact', match_text: '', replacement_name: '' }, return_to: '/transactions' }

    assert_redirected_to '/transactions'
  end
end
