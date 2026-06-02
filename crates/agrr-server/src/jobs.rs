//! In-process job chain dispatcher (`ChainedJobRunnerJob` equivalent).
//!
//! Each [`JobChainDispatcher::enqueue_chain`] call runs its steps **sequentially** on a shared
//! Tokio runtime. **Different chains run concurrently**, so one plan's long `fetch_weather` does
//! not block another plan's optimization chain on the same dispatcher instance.

use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use tokio::runtime::{Handle, Runtime};
use tokio::sync::Semaphore;
use tracing::info;

/// `true` = continue chain; `false` = abort remaining steps (plan failed or already terminal).
pub type JobFuture = Pin<Box<dyn Future<Output = bool> + Send>>;

pub struct JobStep {
    pub name: &'static str,
    pub run: Arc<dyn Fn() -> JobFuture + Send + Sync>,
}

pub struct JobChainDispatcher {
    handle: Handle,
    /// Keeps the runtime alive for the process lifetime.
    _runtime: Arc<Runtime>,
    /// When set, limits how many chains may run their steps concurrently on this dispatcher.
    chain_semaphore: Option<Arc<Semaphore>>,
}

impl JobChainDispatcher {
    pub fn new() -> Self {
        Self::with_max_concurrent_chains(None)
    }

    pub fn with_max_concurrent_chains(max_concurrent_chains: Option<usize>) -> Self {
        let runtime = Arc::new(
            tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("job chain runtime"),
        );
        let handle = runtime.handle().clone();
        let runtime_for_thread = runtime.clone();
        std::thread::spawn(move || {
            runtime_for_thread.block_on(std::future::pending::<()>());
        });
        let chain_semaphore = max_concurrent_chains.map(|n| Arc::new(Semaphore::new(n)));
        Self {
            handle,
            _runtime: runtime,
            chain_semaphore,
        }
    }

    pub fn enqueue_chain(&self, steps: Vec<JobStep>) {
        let handle = self.handle.clone();
        let chain_semaphore = self.chain_semaphore.clone();
        handle.spawn(async move {
            let _permit = match chain_semaphore {
                Some(sem) => Some(
                    sem.acquire_owned()
                        .await
                        .expect("job chain concurrency semaphore closed"),
                ),
                None => None,
            };
            for step in steps {
                info!(step = step.name, "job chain step start");
                let continue_chain = (step.run)().await;
                info!(step = step.name, continue = continue_chain, "job chain step done");
                if !continue_chain {
                    // Remaining steps for this plan would no-op via plan_still_optimizing anyway.
                    break;
                }
            }
        });
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
    use std::thread;

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

    /// Two [`JobChainDispatcher`] instances do not share a queue (farm weather vs plan optimization).
    #[test]
    fn separate_dispatcher_instances_do_not_block_each_other() {
        let weather_dispatcher = JobChainDispatcher::new();
        let optimization_dispatcher = JobChainDispatcher::new();
        let optimization_ran = Arc::new(AtomicBool::new(false));

        weather_dispatcher.enqueue_chain(vec![sleep_step("scheduler_fetch_weather", 500)]);
        optimization_dispatcher.enqueue_chain(vec![flag_step(
            "fetch_weather_data",
            optimization_ran.clone(),
        )]);

        assert!(
            wait_until(Duration::from_millis(200), || {
                optimization_ran.load(Ordering::SeqCst)
            }),
            "optimization dispatcher must run while weather dispatcher is busy"
        );
    }

    /// Separate `enqueue_chain` calls on the same dispatcher run concurrently.
    #[test]
    fn parallel_chains_do_not_block_each_other() {
        let dispatcher = JobChainDispatcher::new();
        let slow_chain_done = Arc::new(AtomicBool::new(false));
        let fast_chain_done = Arc::new(AtomicBool::new(false));

        dispatcher.enqueue_chain(vec![
            sleep_step("slow_plan_fetch", 500),
            flag_step("slow_plan_done", slow_chain_done.clone()),
        ]);
        dispatcher.enqueue_chain(vec![flag_step("fast_plan_fetch", fast_chain_done.clone())]);

        assert!(
            wait_until(Duration::from_millis(200), || fast_chain_done.load(Ordering::SeqCst)),
            "fast chain should finish while slow chain is still on its first step"
        );
        assert!(
            !slow_chain_done.load(Ordering::SeqCst),
            "slow chain must not have reached its second step yet"
        );
        assert!(
            wait_until(Duration::from_secs(2), || slow_chain_done.load(Ordering::SeqCst)),
            "slow chain should eventually complete"
        );
    }

    /// When `max_concurrent_chains` is 1, a second chain waits for the first to finish.
    #[test]
    fn max_concurrent_chains_limits_parallel_execution() {
        let dispatcher = JobChainDispatcher::with_max_concurrent_chains(Some(1));
        let second_started = Arc::new(AtomicBool::new(false));

        dispatcher.enqueue_chain(vec![sleep_step("blocking_first_chain", 300)]);
        dispatcher.enqueue_chain(vec![JobStep {
            name: "second_chain_start",
            run: Arc::new({
                let second_started = second_started.clone();
                move || {
                    let second_started = second_started.clone();
                    Box::pin(async move {
                        second_started.store(true, Ordering::SeqCst);
                        true
                    })
                }
            }),
        }]);

        assert!(
            !wait_until(Duration::from_millis(150), || {
                second_started.load(Ordering::SeqCst)
            }),
            "second chain should wait for first chain to release the semaphore"
        );
        assert!(
            wait_until(Duration::from_secs(2), || second_started.load(Ordering::SeqCst)),
            "second chain should run after first chain completes"
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
