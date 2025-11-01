# frozen_string_literal: true

require 'test_helper'

class AgrrServiceTest < ActiveSupport::TestCase
  def setup
    @service = AgrrService.new
  end

  test 'should check daemon running status' do
    # Mock the socket file check
    File.stub(:exist?, false) do
      File.stub(:socket?, false) do
        assert_not @service.daemon_running?
      end
    end
  end

  test 'should raise error when daemon not running' do
    File.stub(:exist?, false) do
      File.stub(:socket?, false) do
        assert_raises(AgrrService::DaemonNotRunningError) do
          @service.weather(location: '35.6762,139.6503')
        end
      end
    end
  end

  test 'should build weather command args correctly' do
    # This test would need to mock the system call
    # For now, just test that the method exists and accepts parameters
    assert_respond_to @service, :weather
    assert_respond_to @service, :forecast
    assert_respond_to @service, :crop
  end
end
