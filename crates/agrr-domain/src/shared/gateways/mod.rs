//! Ruby: `Domain::Shared::Gateways` — trait-only gateway definitions.

pub mod api_key_principal_gateway;
pub mod session_cookie_principal_gateway;
pub mod user_lookup_gateway;

pub use api_key_principal_gateway::ApiKeyPrincipalGateway;
pub use session_cookie_principal_gateway::SessionCookiePrincipalGateway;
pub use user_lookup_gateway::UserLookupGateway;
