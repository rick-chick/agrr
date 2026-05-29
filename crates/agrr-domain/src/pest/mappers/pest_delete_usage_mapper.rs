//! Ruby: `Domain::Pest::Mappers::PestDeleteUsageMapper`

use crate::pest::dtos::PestDeleteUsage;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PestDeleteUsageWire {
    pub pesticides_count: i64,
}

pub fn from_wire(wire: &PestDeleteUsageWire) -> PestDeleteUsage {
    PestDeleteUsage::new(wire.pesticides_count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_wire_maps_pesticides_count() {
        let wire = PestDeleteUsageWire {
            pesticides_count: 5,
        };

        let dto = from_wire(&wire);

        assert_eq!(dto.pesticides_count, 5);
    }
}
