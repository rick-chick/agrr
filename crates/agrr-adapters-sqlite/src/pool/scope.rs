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
    let conn_ptr = WRITE_SCOPE.with(|cell| {
        cell.borrow()
            .as_ref()
            .map(|conn| conn as *const Connection)
            .expect("write scope connection missing while scope is active")
    });
    // SAFETY: `conn_ptr` points at the thread-local transaction connection, which
    // outlives this call and is only used on the current thread while the write lock
    // is held. Nested `with_write` calls reuse the same pointer without re-borrowing
    // the `RefCell`, which would panic during reentrant plan-save persistence.
    unsafe { f(&*conn_ptr) }
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
