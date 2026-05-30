//! Ruby: `Adapters::Backdoor::Gateways::ShellStdoutCaptureCliGateway`

use std::process::Command;

/// Captures shell stdout for backdoor daemon probes. Failures return `None` (Ruby parity).
pub struct ShellStdoutCaptureCliGateway;

impl ShellStdoutCaptureCliGateway {
    pub fn new() -> Self {
        Self
    }

    /// Runs `command` via `/bin/sh -c` and returns trimmed stdout, or `None` on failure.
    pub fn capture(&self, command: &str) -> Option<String> {
        let output = Command::new("/bin/sh").arg("-c").arg(command).output().ok()?;
        if !output.status.success() {
            return None;
        }
        let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if text.is_empty() {
            None
        } else {
            Some(text)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn capture_runs_simple_echo() {
        let shell = ShellStdoutCaptureCliGateway::new();
        let out = shell.capture("echo hello-backdoor").expect("stdout");
        assert_eq!(out, "hello-backdoor");
    }

    #[test]
    fn capture_returns_none_on_failure() {
        let shell = ShellStdoutCaptureCliGateway::new();
        assert!(shell.capture("exit 42").is_none());
    }
}
