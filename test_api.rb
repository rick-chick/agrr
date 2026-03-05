require 'rails_helper'

describe 'Farm API' do
  it 'returns farm details' do
    get '/api/v1/masters/farms/98', headers: { 'X-API-Key' => 'test_api_key_123' }
    
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['name']).to eq('てｓｔ')
  end
end
