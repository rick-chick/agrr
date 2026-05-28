/// Ruby: `Domain::Shared::Dtos::ReferencableListRow`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReferencableListRow<R> {
    pub record: R,
}

impl<R> ReferencableListRow<R> {
    pub fn new(record: R) -> Self {
        Self { record }
    }
}
