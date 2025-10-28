require "test_helper"

class AuthTestControllerTest < ActionController::TestCase
  tests AuthTestController

  def test_mock_login_redirects_to_process_saved_plan_when_session_data_present
    @request.session[:public_plan_save_data] = {
      plan_id: 1,
      farm_id: 1,
      crop_ids: [],
      field_data: []
    }

    get :mock_login_as, params: { user: 'developer' }
    assert_redirected_to process_saved_plan_public_plans_path
  end
end
