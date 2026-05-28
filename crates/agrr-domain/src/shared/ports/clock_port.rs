use time::{Date, OffsetDateTime};

/// Ruby: `Domain::Shared::Ports::ClockPort`
pub trait ClockPort: Send + Sync {
    fn today(&self) -> Date;
    fn now(&self) -> OffsetDateTime;
}
