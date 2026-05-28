use time::Date;

/// Ruby: weather fetch block `Hash` with `:start_date`, `:end_date`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WeatherFetchDateBlock {
    pub start_date: Date,
    pub end_date: Date,
}
