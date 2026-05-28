/// Ruby: `Domain::Pest::Dtos::PestDeleteUsage`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PestDeleteUsage {
    pub pesticides_count: i64,
}

impl PestDeleteUsage {
    pub fn new(pesticides_count: i64) -> Self {
        Self { pesticides_count }
    }
}
