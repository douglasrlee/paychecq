require 'rails_helper'

RSpec.describe "Transactions", type: :request do
  describe "GET /transactions" do
    context "user is logged in" do
      let(:user) { create(:user) }

      it "returns http success" do
        sign_in(user)

        get "/transactions"

        expect(response).to have_http_status(:success)
      end
    end

    context "user is not logged in" do
      it "returns http redirect" do
        get "/transactions"

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
