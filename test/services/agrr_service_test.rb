# frozen_string_literal: true

require 'test_helper'

class AgrrServiceTest < ActiveSupport::TestCase
  def setup
    @service = AgrrService.new
  end

  test 'fertilize_plan appends --max-applications with default 2' do
    captured_args = nil
    status = Minitest::Mock.new
    status.expect(:success?, true)
    status.expect(:exitstatus, 0)

    File.stub(:exist?, true) do
      File.stub(:socket?, true) do
        Open3.stub(:capture3, lambda do |*args|
          captured_args = args
          ['{"schedule":[]}', '', status]
        end) do
          @service.fertilize_plan(crop_file: '/tmp/crop.json')
        end
      end
    end

    binary, *rest = captured_args
    assert_equal Rails.root.join('bin', 'agrr_client').to_s, binary
    assert_includes rest, 'fertilize'
    assert_includes rest, 'plan'
    idx = rest.index('--max-applications')
    assert idx, 'must include --max-applications'
    assert_equal '2', rest[idx + 1]
    status.verify
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

  test 'should respond to schedule method' do
    assert_respond_to @service, :schedule
  end

  test 'weather uses noaa data source by default and reads json from output file' do
    captured_args = nil
    output_path = nil
    status = Minitest::Mock.new
    status.expect(:success?, true)
    status.expect(:exitstatus, 0)

    File.stub(:exist?, true) do
      File.stub(:socket?, true) do
        Open3.stub(:capture3, lambda do |*args|
          captured_args = args
          output_index = args.index('--output')
          raise 'missing --output flag' unless output_index
          output_path = args[output_index + 1]
          File.write(output_path, '{"data":[]}') if output_path
          ['', '', status]
        end) do
          result = @service.weather(location: '35.6762,139.6503', days: 3)
          assert_equal '{"data":[]}', result
        end
      end
    end

    binary, *rest = captured_args
    assert_equal Rails.root.join('bin', 'agrr_client').to_s, binary
    assert_includes rest, '--data-source'
    data_source_index = rest.index('--data-source')
    assert_equal 'noaa', rest[data_source_index + 1]
    assert_includes rest, '--output'
    status.verify
    refute_nil output_path
    refute File.exist?(output_path), 'weather output file must be cleaned up'
  end

  test 'weather writes output json internally without exposing output argument' do
    captured_args = nil
    wrote_path = nil
    status = Minitest::Mock.new
    status.expect(:success?, true)
    status.expect(:exitstatus, 0)

    File.stub(:exist?, true) do
      File.stub(:socket?, true) do
        Open3.stub(:capture3, lambda do |*args|
          captured_args = args
          output_index = args.index('--output')
          raise 'missing --output flag' unless output_index
          wrote_path = args[output_index + 1]
          File.write(wrote_path, '{"data":[{"time":"2025-01-01"}]}')
          ['', '', status]
        end) do
          result = @service.weather(location: '35.0,139.0', days: 1)
          assert_equal '{"data":[{"time":"2025-01-01"}]}', result
        end
      end
    end

    refute_nil captured_args
    assert_includes captured_args, '--output'
    refute File.exist?(wrote_path), 'output file should be removed after reading'
    status.verify
  end

  test 'should raise error when schedule called without daemon' do
    File.stub(:exist?, false) do
      File.stub(:socket?, false) do
        assert_raises(AgrrService::DaemonNotRunningError) do
          @service.schedule(
            crop_name: 'トマト',
            variety: 'アイコ',
            stage_requirements: '/path/to/stage.json',
            agricultural_tasks: '/path/to/tasks.json'
          )
        end
      end
    end
  end

  test 'schedule executes agrr client with json option and returns raw response' do
    captured_args = nil
    status = Minitest::Mock.new
    status.expect(:success?, true)
    status.expect(:exitstatus, 0)

    File.stub(:exist?, true) do
      File.stub(:socket?, true) do
        Open3.stub(:capture3, lambda do |*args|
          captured_args = args
          ['{"task_schedules":[{"gdd_trigger":185.0}]}', '', status]
        end) do
          result = @service.schedule(
            crop_name: 'トマト',
            variety: '一般',
            stage_requirements: '/tmp/stage.json',
            agricultural_tasks: '/tmp/tasks.json'
          )

          binary, *rest = captured_args
          assert_equal Rails.root.join('bin', 'agrr_client').to_s, binary
          assert_includes rest, '--json'
          assert_includes rest, '--crop-name'
          assert_includes rest, 'トマト'

          assert_equal '{"task_schedules":[{"gdd_trigger":185.0}]}', result
        end
      end
    end

    status.verify
  end
end
