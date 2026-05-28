//! Ruby: `Domain::FileBlob::Interactors::FileBlobCreateInteractor`

use crate::file_blob::dtos::FileBlobCreateUploadInput;
use crate::file_blob::gateways::FileBlobGateway;
use crate::file_blob::ports::FileBlobCreateOutputPort;

/// Ruby: `Domain::FileBlob::Interactors::FileBlobCreateInteractor`
pub struct FileBlobCreateInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> FileBlobCreateInteractor<'a, G, O>
where
    G: FileBlobGateway,
    O: FileBlobCreateOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(&mut self, input: FileBlobCreateUploadInput) {
        if input.upload_blank() {
            self.output_port.on_missing_file();
            return;
        }

        let upload = input.upload.as_ref().expect("upload present when not blank");
        let row = self.gateway.create_from_upload(
            upload,
            &input.filename,
            &input.content_type,
        );
        self.output_port.on_created(&row);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::file_blob::dtos::FileBlobRow;

    struct MockGateway {
        row: FileBlobRow,
    }

    impl FileBlobGateway for MockGateway {
        fn list_rows_ordered_desc(&self) -> Vec<FileBlobRow> {
            vec![]
        }

        fn find_by_id(&self, _blob_id: i64) -> Option<FileBlobRow> {
            None
        }

        fn create_from_upload(
            &self,
            io: &[u8],
            filename: &str,
            content_type: &str,
        ) -> FileBlobRow {
            assert_eq!(io, b"data");
            assert_eq!(filename, "f.bin");
            assert_eq!(content_type, "application/octet-stream");
            self.row.clone()
        }

        fn purge(&self, _blob_id: i64) -> bool {
            false
        }
    }

    struct SpyOutput {
        missing_file: bool,
        created: Option<FileBlobRow>,
    }

    impl FileBlobCreateOutputPort for SpyOutput {
        fn on_missing_file(&mut self) {
            self.missing_file = true;
        }

        fn on_created(&mut self, row: &FileBlobRow) {
            self.created = Some(row.clone());
        }
    }

    // Ruby: test "on_missing_file when upload is blank"
    #[test]
    fn on_missing_file_when_upload_is_blank() {
        let gateway = MockGateway {
            row: FileBlobRow::new(0, "", "", 0, "", ""),
        };
        let mut output = SpyOutput {
            missing_file: false,
            created: None,
        };
        let mut interactor = FileBlobCreateInteractor::new(&mut output, &gateway);

        let input = FileBlobCreateUploadInput::new(None, "x.txt", "text/plain");
        interactor.call(input);

        assert!(output.missing_file);
        assert!(output.created.is_none());
    }

    // Ruby: test "on_created with gateway row dto"
    #[test]
    fn on_created_with_gateway_row_dto() {
        let row = FileBlobRow::new(
            1,
            "f.bin",
            "application/octet-stream",
            4,
            "2026-05-10T12:00:00.000Z",
            "http://example/blob",
        );
        let gateway = MockGateway {
            row: row.clone(),
        };
        let mut output = SpyOutput {
            missing_file: false,
            created: None,
        };
        let mut interactor = FileBlobCreateInteractor::new(&mut output, &gateway);

        let input = FileBlobCreateUploadInput::new(
            Some(b"data".to_vec()),
            "f.bin",
            "application/octet-stream",
        );
        interactor.call(input);

        assert!(!output.missing_file);
        assert_eq!(output.created.as_ref(), Some(&row));
    }
}
