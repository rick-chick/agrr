//! Builds `GET /api/v1/backdoor/status` JSON (Ruby `BackdoorController#status`).

use agrr_adapters_sqlite::ShellStdoutCaptureCliGateway;
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use time::format_description::well_known::Rfc3339;
use time::OffsetDateTime;

const DEFAULT_SOCKET_PATH: &str = "/tmp/agrr.sock";

/// Probe AGRR daemon + binary state for the backdoor status endpoint.
pub fn build_backdoor_status_json(agrr_root: &Path) -> Value {
    let agrr_bin = agrr_root.join("lib").join("core").join("agrr");
    let socket_path = std::env::var("AGRR_DAEMON_SOCKET")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(DEFAULT_SOCKET_PATH));

    let binary_exists = agrr_bin.is_file();
    let binary_executable = binary_exists
        && std::fs::metadata(&agrr_bin)
            .map(|m| {
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    m.permissions().mode() & 0o111 != 0
                }
                #[cfg(not(unix))]
                {
                    let _ = m;
                    true
                }
            })
            .unwrap_or(false);

    let socket_exists = socket_path.exists();
    let daemon_running = socket_exists && path_is_socket(&socket_path);

    let shell = ShellStdoutCaptureCliGateway::new();
    let mut daemon_status_output: Option<String> = None;
    let mut daemon_pid: Option<i64> = None;

    if binary_executable {
        let cmd = format!("{} daemon status 2>&1", agrr_bin.display());
        if let Some(out) = shell.capture(&cmd) {
            daemon_status_output = Some(out.clone());
            daemon_pid = parse_daemon_pid(&out);
        }
    }

    let process = daemon_pid.and_then(|pid| probe_process_info(&shell, pid));

    let service_available = daemon_running && binary_executable;

    let timestamp = OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| OffsetDateTime::now_utc().to_string());

    json!({
        "timestamp": timestamp,
        "daemon": {
            "running": daemon_running,
            "socket_exists": socket_exists,
            "socket_path": socket_path.to_string_lossy(),
        },
        "binary": {
            "exists": binary_exists,
            "executable": binary_executable,
            "path": agrr_bin.to_string_lossy(),
        },
        "status_output": daemon_status_output,
        "process": process,
        "service_available": service_available,
    })
}

fn path_is_socket(path: &Path) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::fs::FileTypeExt;
        std::fs::metadata(path)
            .map(|m| m.file_type().is_socket())
            .unwrap_or(false)
    }
    #[cfg(not(unix))]
    {
        let _ = path;
        false
    }
}

fn parse_daemon_pid(output: &str) -> Option<i64> {
    for line in output.lines() {
        let lower = line.to_lowercase();
        if let Some(rest) = lower.split("pid").nth(1) {
            let digits: String = rest.chars().filter(|c| c.is_ascii_digit()).collect();
            if let Ok(pid) = digits.parse::<i64>() {
                if pid > 0 {
                    return Some(pid);
                }
            }
        }
    }
    None
}

fn probe_process_info(shell: &ShellStdoutCaptureCliGateway, pid: i64) -> Option<Value> {
    let rss_out = shell.capture(&format!("ps -o rss= -p {pid}"))?;
    let etime_out = shell.capture(&format!("ps -o etime= -p {pid}"))?;
    let memory_kb: i64 = rss_out.trim().parse().ok()?;
    let memory_mb = (memory_kb as f64 / 1024.0 * 100.0).round() / 100.0;
    Some(json!({
        "pid": pid,
        "memory_mb": memory_mb,
        "uptime": etime_out.trim(),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_daemon_pid_from_status_output() {
        assert_eq!(
            parse_daemon_pid("AGRR daemon running\nPID: 4242\n"),
            Some(4242)
        );
    }

    #[test]
    fn build_status_json_has_expected_keys() {
        let root = std::env::temp_dir();
        let json = build_backdoor_status_json(&root);
        assert!(json.get("timestamp").is_some());
        assert!(json.get("daemon").is_some());
        assert!(json.get("binary").is_some());
        assert!(json.get("service_available").is_some());
    }
}
