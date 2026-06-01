//! In-process job chain dispatcher (`ChainedJobRunnerJob` equivalent).

use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::info;

/// `true` = continue chain; `false` = abort remaining steps (plan failed or already terminal).
pub type JobFuture = Pin<Box<dyn Future<Output = bool> + Send>>;

pub struct JobStep {
    pub name: &'static str,
    pub run: Arc<dyn Fn() -> JobFuture + Send + Sync>,
}

pub struct JobChainDispatcher {
    tx: mpsc::UnboundedSender<JobStep>,
}

impl JobChainDispatcher {
    pub fn new() -> Self {
        let (tx, mut rx) = mpsc::unbounded_channel::<JobStep>();
        std::thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("job chain runtime");
            rt.block_on(async move {
                while let Some(step) = rx.recv().await {
                    info!(step = step.name, "job chain step start");
                    let continue_chain = (step.run)().await;
                    info!(step = step.name, continue = continue_chain, "job chain step done");
                    // Do not break the worker loop on failure: another plan's chain may already
                    // be queued. Remaining steps for a failed plan no-op via plan_still_optimizing.
                }
            });
        });
        Self { tx }
    }

    pub fn enqueue_chain(&self, steps: Vec<JobStep>) {
        for step in steps {
            let _ = self.tx.send(step);
        }
    }
}

impl Default for JobChainDispatcher {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Arc;
    use std::time::{Duration, Instant};
    use std::{thread, vec};

    fn sleep_step(name: &'static str, millis: u64) -> JobStep {
        JobStep {
            name,
            run: Arc::new(move || {
                Box::pin(async move {
                    tokio::time::sleep(Duration::from_millis(millis)).await;
                    true
                })
            }),
        }
    }

    fn flag_step(name: &'static str, flag: Arc<AtomicBool>) -> JobStep {
        let flag_in = flag.clone();
        JobStep {
            name,
            run: Arc::new(move || {
                let flag = flag_in.clone();
                Box::pin(async move {
                    flag.store(true, Ordering::SeqCst);
                    true
                })
            }),
        }
    }

    fn wait_until(timeout: Duration, mut condition: impl FnMut() -> bool) -> bool {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if condition() {
                return true;
            }
            thread::sleep(Duration::from_millis(10));
        }
        false
    }

    /// Characterization: the in-process dispatcher is strictly FIFO.
    #[test]
    fn serial_queue_runs_steps_in_enqueue_order() {
        let dispatcher = JobChainDispatcher::new();
        let order = Arc::new(std::sync::Mutex::new(Vec::<&'static str>::new()));

        for (label, delay_ms) in [("first", 50u64), ("second", 0)] {
            let order = order.clone();
            dispatcher.enqueue_chain(vec![JobStep {
                name: label,
                run: Arc::new(move || {
                    let order = order.clone();
                    Box::pin(async move {
                        tokio::time::sleep(Duration::from_millis(delay_ms)).await;
                        order.lock().expect("lock").push(label);
                        true
                    })
                }),
            }]);
        }

        assert!(wait_until(Duration::from_secs(2), || {
            order.lock().expect("lock").len() == 2
        }));
        assert_eq!(
            *order.lock().expect("lock"),
            vec!["first", "second"],
            "expected FIFO execution"
        );
    }

    /// Steps enqueued in one `enqueue_chain` call run sequentially.
    #[test]
    fn blocking_first_step_delays_second_step() {
        let dispatcher = JobChainDispatcher::new();
        let second_ran = Arc::new(AtomicBool::new(false));

        dispatcher.enqueue_chain(vec![
            sleep_step("blocking_first", 300),
            flag_step("blocked_second", second_ran.clone()),
        ]);

        assert!(
            !wait_until(Duration::from_millis(100), || second_ran.load(Ordering::SeqCst)),
            "second step should not run while first is still sleeping"
        );
        assert!(
            wait_until(Duration::from_secs(2), || second_ran.load(Ordering::SeqCst)),
            "second step should eventually run after first completes"
        );
    }
}
