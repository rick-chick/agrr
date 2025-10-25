require "test_helper"

class AgrrDaemonStatusTest < ActionDispatch::IntegrationTest
  test "AGRR daemon status check" do
    # AGRRデーモンの状態確認
    agrr_bin = "/app/lib/core/agrr"
    
    # バイナリの存在確認
    assert File.exist?(agrr_bin), "AGRR binary should exist at #{agrr_bin}"
    assert File.executable?(agrr_bin), "AGRR binary should be executable"
    
    # デーモンの状態確認
    daemon_status = `#{agrr_bin} daemon status 2>&1`
    puts "Daemon status output: #{daemon_status}"
    
    # デーモンが起動しているかチェック
    if daemon_status.include?("running") || daemon_status.include?("PID:")
      puts "✓ AGRR daemon is running"
      assert true, "AGRR daemon should be running"
    else
      puts "✗ AGRR daemon is not running"
      puts "Attempting to start daemon..."
      
      # デーモンを起動
      start_result = `#{agrr_bin} daemon start 2>&1`
      puts "Daemon start output: #{start_result}"
      
      # 少し待ってから再度確認
      sleep 2
      daemon_status_after = `#{agrr_bin} daemon status 2>&1`
      puts "Daemon status after start: #{daemon_status_after}"
      
      if daemon_status_after.include?("running") || daemon_status_after.include?("PID:")
        puts "✓ AGRR daemon started successfully"
        assert true, "AGRR daemon should be running after start"
      else
        puts "✗ Failed to start AGRR daemon"
        assert false, "AGRR daemon should be running after start attempt"
      end
    end
    
    # ソケットファイルの確認
    socket_path = "/tmp/agrr.sock"
    if File.exist?(socket_path)
      puts "✓ AGRR daemon socket exists at #{socket_path}"
      assert true, "AGRR daemon socket should exist"
    else
      puts "✗ AGRR daemon socket not found at #{socket_path}"
      assert false, "AGRR daemon socket should exist"
    end
  end
end
