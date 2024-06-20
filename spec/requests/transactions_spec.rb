# frozen_string_literal: true

require 'rails_helper'

::RSpec.describe('Transactions') do
  describe 'GET /transactions' do
    context 'when user is logged in' do
      let(:user) { create(:user) }

      it 'returns http success' do
        sign_in(user)

        get '/transactions'

        expect(response).to(have_http_status(:success))
      end
    end

    context 'when user is not logged in' do
      it 'returns http redirect' do
        get '/transactions'

        expect(response).to(have_http_status(:redirect))
      end
    end
  end
end
