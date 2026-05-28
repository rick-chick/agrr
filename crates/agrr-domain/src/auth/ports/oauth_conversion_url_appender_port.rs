/// Edge-injected helper (Ruby: `CompositionRoot.oauth_conversion_url_appender`).
pub trait OauthConversionUrlAppenderPort: Send + Sync {
    fn append(&self, pending_return_to: &str) -> String;
}
