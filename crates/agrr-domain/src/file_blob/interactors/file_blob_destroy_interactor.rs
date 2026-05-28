//! Ruby: `Domain::FileBlob::Interactors::FileBlobDestroyInteractor`

use crate::file_blob::gateways::FileBlobGateway;
use crate::file_blob::ports::FileBlobDestroyOutputPort;

/// Ruby: `Domain::FileBlob::Interactors::FileBlobDestroyInteractor`
pub struct FileBlobDestroyInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> FileBlobDestroyInteractor<'a, G, O>
where
    G: FileBlobGateway,
    O: FileBlobDestroyOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(&mut self, blob_id: i64) {
        if !self.gateway.purge(blob_id) {
            self.output_port.on_not_found();
            return;
        }
        self.output_port.on_deleted();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::file_blob::dtos::FileBlobRow;

    struct MockGateway {
        purge_result: bool,
        last_blob_id: Option<i64>,
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
            _io: &[u8],
            _filename: &str,
            _content_type: &str,
        ) -> FileBlobRow {
            panic!("create_from_upload should not be called")
        }

        fn purge(&self, blob_id: i64) -> bool {
            assert_eq!(Some(blob_id), self.last_blob_id);
            self.purge_result
        }
    }

    struct SpyOutput {
        not_found: bool,
        deleted: bool,
    }

    impl FileBlobDestroyOutputPort for SpyOutput {
        fn on_not_found(&mut self) {
            self.not_found = true;
        }

        fn on_deleted(&mut self) {
            self.deleted = true;
        }
    }

    // Ruby: test "on_not_found when purge did not delete"
    #[test]
    fn on_not_found_when_purge_did_not_delete() {
        let gateway = MockGateway {
            purge_result: false,
            last_blob_id: Some(99),
        };
        let mut output = SpyOutput {
            not_found: false,
            deleted: false,
        };
        let mut interactor = FileBlobDestroyInteractor::new(&mut output, &gateway);

        interactor.call(99);

        assert!(output.not_found);
        assert!(!output.deleted);
    }

    // Ruby: test "on_deleted when purged"
    #[test]
    fn on_deleted_when_purged() {
        let gateway = MockGateway {
            purge_result: true,
            last_blob_id: Some(42),
        };
        let mut output = SpyOutput {
            not_found: false,
            deleted: false,
        };
        let mut interactor = FileBlobDestroyInteractor::new(&mut output, &gateway);

        interactor.call(42);

        assert!(!output.not_found);
        assert!(output.deleted);
    }
}
