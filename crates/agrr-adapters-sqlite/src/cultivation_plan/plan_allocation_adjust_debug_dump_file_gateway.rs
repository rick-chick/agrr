//! Ruby: `Adapters::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpFileGateway`

use std::path::PathBuf;

use agrr_domain::cultivation_plan::gateways::PlanAllocationAdjustDebugDumpGateway;
use agrr_domain::shared::ports::{ClockPort, LoggerPort};
use serde_json::{json, Value};

/// Writes adjust interactor payloads to `{root}/tmp/debug/adjust_*_{ts}.json` (non-production edge wiring).
pub struct PlanAllocationAdjustDebugDumpFileGateway<'a> {
    root_path: PathBuf,
    clock: &'a dyn ClockPort,
    logger: &'a dyn LoggerPort,
}

impl<'a> PlanAllocationAdjustDebugDumpFileGateway<'a> {
    pub fn new(
        root_path: PathBuf,
        clock: &'a dyn ClockPort,
        logger: &'a dyn LoggerPort,
    ) -> Self {
        Self {
            root_path,
            clock,
            logger,
        }
    }

    fn debug_dir(&self) -> PathBuf {
        self.root_path.join("tmp/debug")
    }

    fn write_pretty(&self, path: PathBuf, value: &Value) {
        match serde_json::to_string_pretty(value) {
            Ok(body) => {
                if let Err(e) = std::fs::write(&path, body) {
                    self.logger
                        .error(&format!("failed to write debug dump {}: {e}", path.display()));
                } else {
                    self.logger
                        .info(&format!("📁 [Adjust] Debug saved to: {}", path.display()));
                }
            }
            Err(e) => self.logger.error(&format!("failed to serialize debug dump: {e}")),
        }
    }
}

impl PlanAllocationAdjustDebugDumpGateway for PlanAllocationAdjustDebugDumpFileGateway<'_> {
    fn dump_payload(
        &self,
        current_allocation: &Value,
        moves: &[Value],
        fields: &[Value],
        crops: &[Value],
    ) {
        let debug_dir = self.debug_dir();
        if let Err(e) = std::fs::create_dir_all(&debug_dir) {
            self.logger
                .error(&format!("failed to create debug dir {}: {e}", debug_dir.display()));
            return;
        }

        let ts = self.clock.now().unix_timestamp();
        let paths = [
            (
                debug_dir.join(format!("adjust_current_allocation_{ts}.json")),
                current_allocation.clone(),
            ),
            (
                debug_dir.join(format!("adjust_moves_{ts}.json")),
                json!({ "moves": moves }),
            ),
            (
                debug_dir.join(format!("adjust_fields_{ts}.json")),
                json!({ "fields": fields }),
            ),
            (
                debug_dir.join(format!("adjust_crops_{ts}.json")),
                json!({ "crops": crops }),
            ),
        ];

        for (path, value) in paths {
            self.write_pretty(path, &value);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::shared::ports::ClockPort;
    use std::sync::Mutex;
    use time::{Date, OffsetDateTime};

    struct FixedClock(OffsetDateTime);
    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.0.date()
        }
        fn now(&self) -> OffsetDateTime {
            self.0
        }
    }

    struct CapturingLogger(Mutex<Vec<String>>);
    impl LoggerPort for CapturingLogger {
        fn info(&self, message: &str) {
            self.0.lock().unwrap().push(message.to_string());
        }
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    #[test]
    fn dump_payload_writes_four_json_files_under_tmp_debug() {
        let root = tempfile::tempdir().expect("tempdir");
        let clock = FixedClock(
            OffsetDateTime::from_unix_timestamp(1_700_000_000).expect("unix"),
        );
        let logger = CapturingLogger(Mutex::new(Vec::new()));
        let gateway = PlanAllocationAdjustDebugDumpFileGateway::new(
            root.path().to_path_buf(),
            &clock,
            &logger,
        );

        gateway.dump_payload(
            &json!({"field_schedules": []}),
            &[json!({"allocation_id": 1})],
            &[json!({"field_id": "f1"})],
            &[json!({"crop_id": "c1"})],
        );

        let debug_dir = root.path().join("tmp/debug");
        assert!(debug_dir.join("adjust_current_allocation_1700000000.json").is_file());
        assert!(debug_dir.join("adjust_moves_1700000000.json").is_file());
        assert!(debug_dir.join("adjust_fields_1700000000.json").is_file());
        assert!(debug_dir.join("adjust_crops_1700000000.json").is_file());

        let moves_body =
            std::fs::read_to_string(debug_dir.join("adjust_moves_1700000000.json")).unwrap();
        assert!(moves_body.contains("allocation_id"));
    }
}
