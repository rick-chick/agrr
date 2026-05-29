//! agrr-server runtime environment (decoupled from Rails `RAILS_ENV` naming).

/// Effective environment name (`development` | `test` | `production`).
/// Prefer `AGRR_ENV`; `RAILS_ENV` is accepted for legacy compose/scripts.
pub fn runtime_env() -> String {
    std::env::var("AGRR_ENV")
        .or_else(|_| std::env::var("RAILS_ENV"))
        .unwrap_or_else(|_| "development".into())
}

pub fn is_production() -> bool {
    runtime_env() == "production"
}

/// Mock login (`/auth/test/*`) and insecure session cookies in non-production.
pub fn dev_environment_allowed() -> bool {
    if std::env::var("ENABLE_MOCK_AUTH").as_deref() == Ok("1") {
        return true;
    }
    matches!(runtime_env().as_str(), "development" | "test")
}

/// Set default `AGRR_ENV` when neither `AGRR_ENV` nor `RAILS_ENV` is set (pre-runtime only).
pub fn ensure_default_runtime_env() {
    if std::env::var("AGRR_ENV").is_err() && std::env::var("RAILS_ENV").is_err() {
        // SAFETY: no other threads exist yet (pre-runtime).
        unsafe { std::env::set_var("AGRR_ENV", "development") };
        eprintln!("agrr-server: AGRR_ENV unset; defaulting to development");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dev_environment_allowed_respects_enable_mock_auth() {
        let prev_mock = std::env::var("ENABLE_MOCK_AUTH").ok();
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_rails = std::env::var("RAILS_ENV").ok();

        std::env::set_var("ENABLE_MOCK_AUTH", "1");
        std::env::set_var("AGRR_ENV", "production");
        std::env::remove_var("RAILS_ENV");
        assert!(dev_environment_allowed());

        std::env::remove_var("ENABLE_MOCK_AUTH");
        std::env::set_var("AGRR_ENV", "development");
        assert!(dev_environment_allowed());

        restore_env("ENABLE_MOCK_AUTH", prev_mock);
        restore_env("AGRR_ENV", prev_env);
        restore_env("RAILS_ENV", prev_rails);
    }

    fn restore_env(key: &str, value: Option<String>) {
        match value {
            Some(v) => std::env::set_var(key, v),
            None => std::env::remove_var(key),
        }
    }
}
