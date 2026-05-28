//! Ruby: `Domain::ApiKeys::Ports`

mod user_api_key_rotate_output_port;

pub use user_api_key_rotate_output_port::UserApiKeyRotateOutputPort;

#[cfg(test)]
mod tests {
    use super::*;

    struct NoopOutput;

    impl UserApiKeyRotateOutputPort for NoopOutput {
        fn on_success(&mut self, _: String) {}
        fn on_failure(&mut self, _: String) {}
    }

    #[test]
    fn user_api_key_rotate_output_port_is_object_safe() {
        let mut port: Box<dyn UserApiKeyRotateOutputPort> = Box::new(NoopOutput);
        port.on_success("key".into());
        port.on_failure("err".into());
    }
}
