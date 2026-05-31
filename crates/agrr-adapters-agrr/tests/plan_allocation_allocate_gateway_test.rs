//! Plan allocation allocate gateway — temp files must survive until agrr daemon returns.

use agrr_adapters_agrr::write_temp_json_path;
use serde_json::json;
use std::path::PathBuf;

#[test]
fn interaction_rules_temp_file_exists_when_path_is_passed_to_daemon() {
    let rules = json!([{ "rule": "continuous_cultivation" }]);
    let rules_path: PathBuf = write_temp_json_path(&rules, "allocate_rules").unwrap();
    assert!(
        rules_path.exists(),
        "rules file must exist when path is passed to agrr daemon"
    );
    let _ = std::fs::remove_file(&rules_path);
}
