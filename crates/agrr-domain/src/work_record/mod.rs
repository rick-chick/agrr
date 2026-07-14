//! Ruby: `Domain::WorkRecord`

pub mod dtos;
pub mod entities;
pub mod gateways;
pub mod interactors;
pub mod policies;
pub mod ports;

pub use interactors::private_plan_access::access_allowed as plan_access_allowed;
