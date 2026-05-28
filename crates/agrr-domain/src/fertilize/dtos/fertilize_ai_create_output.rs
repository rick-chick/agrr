use crate::fertilize::dtos::HttpStatus;

/// Ruby: `Domain::Fertilize::Dtos::FertilizeAiCreateOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct FertilizeAiCreateOutput {
    pub http_status: HttpStatus,
    pub success: bool,
    pub fertilize_id: i64,
    pub fertilize_name: String,
    pub n: Option<f64>,
    pub p: Option<f64>,
    pub k: Option<f64>,
    pub description: Option<String>,
    pub package_size: Option<f64>,
    pub message: String,
}

impl FertilizeAiCreateOutput {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        http_status: HttpStatus,
        fertilize_id: i64,
        fertilize_name: impl Into<String>,
        n: Option<f64>,
        p: Option<f64>,
        k: Option<f64>,
        description: Option<String>,
        package_size: Option<f64>,
        message: impl Into<String>,
    ) -> Self {
        Self {
            http_status,
            success: true,
            fertilize_id,
            fertilize_name: fertilize_name.into(),
            n,
            p,
            k,
            description,
            package_size,
            message: message.into(),
        }
    }
}
