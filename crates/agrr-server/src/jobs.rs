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
