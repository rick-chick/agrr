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
    if is_production() {
        return false;
    }
    if std::env::var("ENABLE_MOCK_AUTH").as_deref() == Ok("1") {
        return true;
    }
    matches!(runtime_env().as_str(), "development" | "test")
}

/// Fail-fast when production is combined with mock-auth override (misconfiguration).
pub fn validate_runtime_env_for_startup() {
    if is_production() && std::env::var("ENABLE_MOCK_AUTH").as_deref() == Ok("1") {
        panic!(
            "agrr-server: ENABLE_MOCK_AUTH=1 is forbidden when AGRR_ENV=production"
        );
    }
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
    fn dev_environment_allowed_respects_enable_mock_auth_outside_production() {
        let prev_mock = std::env::var("ENABLE_MOCK_AUTH").ok();
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_rails = std::env::var("RAILS_ENV").ok();

        std::env::set_var("ENABLE_MOCK_AUTH", "1");
        std::env::set_var("AGRR_ENV", "development");
        std::env::remove_var("RAILS_ENV");
        assert!(dev_environment_allowed());

        std::env::remove_var("ENABLE_MOCK_AUTH");
        std::env::set_var("AGRR_ENV", "test");
        assert!(dev_environment_allowed());

        restore_env("ENABLE_MOCK_AUTH", prev_mock);
        restore_env("AGRR_ENV", prev_env);
        restore_env("RAILS_ENV", prev_rails);
    }

    #[test]
    fn dev_environment_allowed_is_false_in_production_even_with_enable_mock_auth() {
        let prev_mock = std::env::var("ENABLE_MOCK_AUTH").ok();
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_rails = std::env::var("RAILS_ENV").ok();

        std::env::set_var("ENABLE_MOCK_AUTH", "1");
        std::env::set_var("AGRR_ENV", "production");
        std::env::remove_var("RAILS_ENV");
        assert!(!dev_environment_allowed());

        std::env::remove_var("ENABLE_MOCK_AUTH");
        assert!(!dev_environment_allowed());

        restore_env("ENABLE_MOCK_AUTH", prev_mock);
        restore_env("AGRR_ENV", prev_env);
        restore_env("RAILS_ENV", prev_rails);
    }

    #[test]
    fn validate_runtime_env_for_startup_rejects_production_with_enable_mock_auth() {
        let prev_mock = std::env::var("ENABLE_MOCK_AUTH").ok();
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_rails = std::env::var("RAILS_ENV").ok();

        std::env::set_var("ENABLE_MOCK_AUTH", "1");
        std::env::set_var("AGRR_ENV", "production");
        std::env::remove_var("RAILS_ENV");

        let err = std::panic::catch_unwind(|| validate_runtime_env_for_startup())
            .err()
            .expect("production + ENABLE_MOCK_AUTH must panic at startup");

        let message = err
            .downcast_ref::<String>()
            .map(|s| s.as_str())
            .or_else(|| err.downcast_ref::<&str>().copied())
            .unwrap_or_default();
        assert!(
            message.contains("ENABLE_MOCK_AUTH"),
            "panic message should mention ENABLE_MOCK_AUTH: {message}"
        );

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
