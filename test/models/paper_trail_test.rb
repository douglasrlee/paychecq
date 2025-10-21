require "test_helper"

class PaperTrailTest < ActiveSupport::TestCase
  test "paper_trail is enabled for User and creates versions on create/update/destroy" do
    previously_enabled = PaperTrail.enabled?
    PaperTrail.enabled = true
    PaperTrail.request.enable_model(User)

    begin
      assert PaperTrail.request.enabled_for_model?(User), "PaperTrail should be enabled for User model"

      PaperTrail.request(whodunnit: "test-user") do
        assert_difference -> { PaperTrail::Version.count }, +1 do
          @user = User.create!(
            first_name: "PT",
            last_name: "Tester",
            email: "pt@example.com",
            password: "password",
            password_confirmation: "password"
          )
        end

        assert_difference -> { PaperTrail::Version.where(item_type: "User", item_id: @user.id.to_s).count }, +1 do
          @user.update!(first_name: "PT2")
        end

        assert_difference -> { PaperTrail::Version.where(item_type: "User", item_id: @user.id.to_s).count }, +1 do
          @user.destroy!
        end
      end

      versions = PaperTrail::Version.where(item_type: "User", item_id: @user.id.to_s).order(:created_at)

      assert_equal %w[create update destroy], versions.pluck(:event)
    ensure
      PaperTrail.enabled = previously_enabled
    end
  end
end
