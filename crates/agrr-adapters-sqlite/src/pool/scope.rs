//! Thread-local write connection scope for nested gateway calls inside SQL transactions.

use rusqlite::Connection;
use std::cell::RefCell;

thread_local! {
    static WRITE_SCOPE: RefCell<Option<Connection>> = const { RefCell::new(None) };
}

pub(crate) fn is_active() -> bool {
    WRITE_SCOPE.with(|slot| slot.borrow().is_some())
}

pub(crate) fn with_borrow<F, T>(f: F) -> rusqlite::Result<T>
where
    F: FnOnce(&Connection) -> rusqlite::Result<T>,
{
    WRITE_SCOPE.with(|slot| {
        let borrowed = slot.borrow();
        let conn = borrowed
            .as_ref()
            .expect("write scope connection missing while scope is active");
        f(conn)
    })
}

pub(crate) fn enter(conn: Connection) {
    WRITE_SCOPE.with(|slot| {
        let mut borrowed = slot.borrow_mut();
        assert!(
            borrowed.is_none(),
            "write scope already active; nested scopes require with_write_transaction_scoped"
        );
        *borrowed = Some(conn);
    });
}

pub(crate) fn take() -> Connection {
    WRITE_SCOPE.with(|slot| {
        slot.borrow_mut()
            .take()
            .expect("write scope connection missing on take")
    })
}
