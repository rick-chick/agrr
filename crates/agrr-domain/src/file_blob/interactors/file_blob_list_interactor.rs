//! Ruby: `Domain::FileBlob::Interactors::FileBlobListInteractor`

use crate::file_blob::gateways::FileBlobGateway;
use crate::file_blob::ports::FileBlobListOutputPort;

/// Ruby: `Domain::FileBlob::Interactors::FileBlobListInteractor`
pub struct FileBlobListInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> FileBlobListInteractor<'a, G, O>
where
    G: FileBlobGateway,
    O: FileBlobListOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(&mut self) {
        let rows = self.gateway.list_rows_ordered_desc();
        self.output_port.on_list_success(&rows);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::file_blob::dtos::FileBlobRow;

    struct MockGateway {
        rows: Vec<FileBlobRow>,
    }

    impl FileBlobGateway for MockGateway {
        fn list_rows_ordered_desc(&self) -> Vec<FileBlobRow> {
            self.rows.clone()
        }

        fn find_by_id(&self, _blob_id: i64) -> Option<FileBlobRow> {
            None
        }

        fn create_from_upload(
            &self,
            _io: &[u8],
            _filename: &str,
            _content_type: &str,
        ) -> FileBlobRow {
            panic!("create_from_upload should not be called")
        }

        fn purge(&self, _blob_id: i64) -> bool {
            false
        }
    }

    struct SpyOutput {
        rows: Option<Vec<FileBlobRow>>,
    }

    impl FileBlobListOutputPort for SpyOutput {
        fn on_list_success(&mut self, rows: &[FileBlobRow]) {
            self.rows = Some(rows.to_vec());
        }
    }

    #[test]
    fn on_list_success_with_gateway_rows() {
        let rows = vec![FileBlobRow::new(
            1,
            "f.bin",
            "application/octet-stream",
            4,
            "2026-05-10T12:00:00.000Z",
            "http://example/blob",
        )];
        let gateway = MockGateway {
            rows: rows.clone(),
        };
        let mut output = SpyOutput { rows: None };
        let mut interactor = FileBlobListInteractor::new(&mut output, &gateway);

        interactor.call();

        assert_eq!(output.rows.as_ref(), Some(&rows));
    }
}
