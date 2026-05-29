//! In-process job chain dispatcher (`ChainedJobRunnerJob` equivalent).

use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::info;

pub type JobFuture = Pin<Box<dyn Future<Output = ()> + Send>>;

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
        tokio::spawn(async move {
            while let Some(step) = rx.recv().await {
                info!(step = step.name, "job chain step start");
                (step.run)().await;
                info!(step = step.name, "job chain step done");
            }
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
