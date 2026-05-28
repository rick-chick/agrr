//! Shared fakes for plan_save interactor unit tests (Ruby domain-lib parity).

#![cfg(test)]

use std::collections::BTreeMap;
use std::sync::Mutex;

use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::ports::{ClockPort, TranslatorPort, TranslateOptions};
use time::{Date, OffsetDateTime};

pub struct FakeTranslator;

impl TranslatorPort for FakeTranslator {
    fn translate(&self, key: &str, options: &TranslateOptions) -> String {
        if options.is_empty() {
            key.to_string()
        } else {
            let mut parts: Vec<_> = options.iter().collect();
            parts.sort_by(|a, b| a.0.cmp(&b.0));
            let inner: String = parts
                .iter()
                .map(|(k, v)| format!(":{k}=>{v}"))
                .collect::<Vec<_>>()
                .join(", ");
            format!("{key}|{{{inner}}}")
        }
    }

    fn localize(&self, _date: Date, _format: Option<&str>, _options: &TranslateOptions) -> String {
        String::new()
    }
}

pub struct CapturingLogger {
    pub entries: Mutex<Vec<(LogLevel, String)>>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LogLevel {
    Info,
    Warn,
    Error,
    Debug,
}

impl CapturingLogger {
    pub fn new() -> Self {
        Self {
            entries: Mutex::new(Vec::new()),
        }
    }
}

impl LoggerPort for CapturingLogger {
    fn info(&self, message: &str) {
        self.entries
            .lock()
            .unwrap()
            .push((LogLevel::Info, message.to_string()));
    }
    fn warn(&self, message: &str) {
        self.entries
            .lock()
            .unwrap()
            .push((LogLevel::Warn, message.to_string()));
    }
    fn error(&self, message: &str) {
        self.entries
            .lock()
            .unwrap()
            .push((LogLevel::Error, message.to_string()));
    }
    fn debug(&self, message: &str) {
        self.entries
            .lock()
            .unwrap()
            .push((LogLevel::Debug, message.to_string()));
    }
}

pub struct FixedClock {
    pub now: OffsetDateTime,
}

impl ClockPort for FixedClock {
    fn today(&self) -> Date {
        self.now.date()
    }

    fn now(&self) -> OffsetDateTime {
        self.now
    }
}

pub fn fixed_clock_utc_2026_05_25_12_34_56() -> FixedClock {
    FixedClock {
        now: OffsetDateTime::from_unix_timestamp(1_779_712_496).unwrap(),
    }
}

pub fn attrs_has_entries(map: &BTreeMap<String, serde_json::Value>, expected: &[(&str, serde_json::Value)]) {
    for (key, value) in expected {
        assert_eq!(
            map.get(*key),
            Some(value),
            "missing or mismatched key {key}"
        );
    }
}
