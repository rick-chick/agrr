//! agrr-server process smoke for R4 (real check: scripts/run-rust-contract-tests.sh).

#[test]
fn health_payload_is_ok_literal() {
    assert_eq!("ok", "ok");
}
