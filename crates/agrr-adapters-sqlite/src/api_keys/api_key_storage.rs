//! API key hashing and constant-time verification for SQLite storage.

use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;

pub const API_KEY_PREFIX_LEN: usize = 8;

/// First `API_KEY_PREFIX_LEN` characters for display and lookup narrowing.
pub fn api_key_prefix(raw: &str) -> String {
    let end = raw.len().min(API_KEY_PREFIX_LEN);
    raw[..end].to_string()
}

/// SHA-256 hex digest of the raw API key (64 hex chars).
pub fn hash_api_key(raw: &str) -> String {
    let digest = Sha256::digest(raw.as_bytes());
    digest.iter().map(|b| format!("{b:02x}")).collect()
}

/// Constant-time comparison of stored hash vs hash of the provided key.
pub fn verify_api_key_hash(provided: &str, stored_hash: &str) -> bool {
    let computed = hash_api_key(provided);
    let a = computed.as_bytes();
    let b = stored_hash.as_bytes();
    if a.len() != b.len() {
        return false;
    }
    a.ct_eq(b).into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_is_deterministic_and_not_plaintext() {
        let raw = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
        let hash = hash_api_key(raw);
        assert_eq!(hash, hash_api_key(raw));
        assert_ne!(hash, raw);
        assert_eq!(hash.len(), 64);
    }

    #[test]
    fn verify_accepts_matching_key_and_rejects_mismatch() {
        let raw = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
        let hash = hash_api_key(raw);
        assert!(verify_api_key_hash(raw, &hash));
        assert!(!verify_api_key_hash("wrong-key", &hash));
    }

    #[test]
    fn prefix_is_first_eight_chars() {
        let raw = "abcdef0123456789";
        assert_eq!(api_key_prefix(raw), "abcdef01");
    }

    #[test]
    fn prefix_short_key_uses_full_length() {
        assert_eq!(api_key_prefix("short"), "short");
    }
}
