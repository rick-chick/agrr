class FertilizeAiGatewayStub
  attr_reader :create_calls, :update_calls

  def initialize(success_response:, error_response:)
    @success_response = success_response
    @error_response = error_response
    @create_calls = []
    @update_calls = []
  end

  def fetch_for_create(name:)
    @create_calls << { name: name }
    response_payload
  end

  def fetch_for_update(id:, name:)
    @update_calls << { id: id, name: name }
    response_payload
  end

  private

  def response_payload
    return @success_response if @success_response
    if @error_response
      @error_response
    else
      { "success" => false, "error" => "stub not configured" }
    end
  end
end

