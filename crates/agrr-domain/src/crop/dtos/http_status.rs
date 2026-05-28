#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HttpStatus {
    BadRequest,
    Unauthorized,
    UnprocessableEntity,
    ServiceUnavailable,
}
