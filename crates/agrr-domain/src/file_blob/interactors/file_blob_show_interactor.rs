//! Ruby: `Domain::FileBlob::Interactors::FileBlobShowInteractor`

use crate::file_blob::gateways::FileBlobGateway;
use crate::file_blob::ports::FileBlobShowOutputPort;

/// Ruby: `Domain::FileBlob::Interactors::FileBlobShowInteractor`
pub struct FileBlobShowInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> FileBlobShowInteractor<'a, G, O>
where
    G: FileBlobGateway,
    O: FileBlobShowOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(&mut self, blob_id: i64) {
        let Some(row) = self.gateway.find_by_id(blob_id) else {
            self.output_port.on_not_found();
            return;
        };
        self.output_port.on_show_success(&row);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::file_blob::dtos::FileBlobRow;

    struct MockGateway {
        row: Option<FileBlobRow>,
    }

    impl FileBlobGateway for MockGateway {
        fn list_rows_ordered_desc(&self) -> Vec<FileBlobRow> {
            vec![]
        }

        fn find_by_id(&self, _blob_id: i64) -> Option<FileBlobRow> {
            self.row.clone()
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
        not_found: bool,
        row: Option<FileBlobRow>,
    }

    impl FileBlobShowOutputPort for SpyOutput {
        fn on_not_found(&mut self) {
            self.not_found = true;
        }

        fn on_show_success(&mut self, row: &FileBlobRow) {
            self.row = Some(row.clone());
        }
    }

    #[test]
    fn on_not_found_when_row_missing() {
        let gateway = MockGateway { row: None };
        let mut output = SpyOutput {
            not_found: false,
            row: None,
        };
        let mut interactor = FileBlobShowInteractor::new(&mut output, &gateway);

        interactor.call(99);

        assert!(output.not_found);
        assert!(output.row.is_none());
    }

    #[test]
    fn on_show_success_when_row_present() {
        let row = FileBlobRow::new(
            1,
            "f.bin",
            "application/octet-stream",
            4,
            "2026-05-10T12:00:00.000Z",
            "http://example/blob",
        );
        let gateway = MockGateway {
            row: Some(row.clone()),
        };
        let mut output = SpyOutput {
            not_found: false,
            row: None,
        };
        let mut interactor = FileBlobShowInteractor::new(&mut output, &gateway);

        interactor.call(1);

        assert!(!output.not_found);
        assert_eq!(output.row.as_ref(), Some(&row));
    }
}
