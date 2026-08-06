/// Referencable record surface (Ruby duck-typed `is_reference` / `user_id` / `organization_id`).
pub trait RecordRef {
    fn is_reference(&self) -> bool;
    fn user_id(&self) -> Option<i64>;
    fn organization_id(&self) -> Option<i64> {
        None
    }
}

#[cfg(test)]
#[derive(Debug, Clone, Copy)]
pub struct RecordStub {
    pub is_reference: bool,
    pub user_id: Option<i64>,
    pub organization_id: Option<i64>,
}

#[cfg(test)]
impl RecordRef for RecordStub {
    fn is_reference(&self) -> bool {
        self.is_reference
    }

    fn user_id(&self) -> Option<i64> {
        self.user_id
    }

    fn organization_id(&self) -> Option<i64> {
        self.organization_id
    }
}
