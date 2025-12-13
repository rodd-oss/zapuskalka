use std::sync::Arc;

use tauri::async_runtime::spawn;
use tokio::{
    process::Child,
    sync::{broadcast, oneshot, Mutex},
};

pub struct ProcessMonitor {
    events_channel: broadcast::Sender<ProcessEvent>,
    processes: Arc<Mutex<Vec<ProcessEntry>>>,
}

impl ProcessMonitor {
    pub fn new() -> (Self, broadcast::Receiver<ProcessEvent>) {
        let (tx, rx) = broadcast::channel(1);

        let processes = Arc::new(Mutex::new(vec![]));
        let procs_for_cleanup = processes.clone();
        let mut rx_clone = rx.resubscribe();

        // cleanup listener
        spawn(async move {
            while let Ok(ev) = rx_clone.recv().await {
                match ev {
                    ProcessEvent::Terminated(pid) => {
                        _ = Self::remove_process(procs_for_cleanup.clone(), pid).await;
                    }
                }
            }
        });

        (
            Self {
                events_channel: tx,
                processes,
            },
            rx,
        )
    }

    /// Add process to monitoring
    pub async fn add(&mut self, process: Child) {
        let (m2w_tx, m2w_rx) = oneshot::channel();
        let pid = process.id().unwrap();

        spawn(Self::child_close_waiter(
            process,
            m2w_rx,
            self.events_channel.clone(),
        ));

        let mut procs = self.processes.lock().await;
        procs.push(ProcessEntry { pid, tx: m2w_tx });
        println!("Monitoring process count: {} (+1)", procs.len());
    }

    /// Terminate and remove process from monitoring
    pub async fn terminate(&mut self, pid: u32) -> Result<(), Error> {
        match Self::remove_process(self.processes.clone(), pid).await {
            Ok(tx) => {
                _ = tx.send(Monitor2Waiter::TerminateChild);
                Ok(())
            }
            Err(e) => Err(e),
        }
    }

    async fn remove_process(
        procs: Arc<Mutex<Vec<ProcessEntry>>>,
        pid: u32,
    ) -> Result<oneshot::Sender<Monitor2Waiter>, Error> {
        let mut procs = procs.lock().await;
        let proc = procs.iter().enumerate().find(|(_, it)| it.pid == pid);
        if let Some((idx, _)) = proc {
            let entry = procs.swap_remove(idx);
            println!("Monitoring process count: {} (-1)", procs.len());
            Ok(entry.tx)
        } else {
            Err(Error::ProcessNotFound)
        }
    }

    async fn child_close_waiter(
        mut child: Child,
        rx: oneshot::Receiver<Monitor2Waiter>,
        tx: broadcast::Sender<ProcessEvent>,
    ) {
        let pid = if let Some(v) = child.id() {
            v
        } else {
            eprintln!("Enable to get child PID");
            return;
        };

        tokio::select! {
            res = child.wait() => {
                if let Err(e) = res {
                    eprintln!("{}", e);
                }
            }

            msg = rx => {
                match msg {
                    Ok(Monitor2Waiter::TerminateChild) => {
                        if let Err(e) = child.kill().await {
                            eprintln!("Error during terminating process: {}", e);
                        } else {
                            _ = tx.send(ProcessEvent::Terminated(pid));
                        }
                    }
                    Err(e) => {
                        eprintln!("Error during receiving channel message: {}", e);
                    }
                }
            }
        }
    }
}

struct ProcessEntry {
    pub pid: u32,
    pub tx: oneshot::Sender<Monitor2Waiter>,
}

#[derive(Debug)]
pub enum Error {
    ProcessNotFound,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ProcessEvent {
    Terminated(u32),
}

enum Monitor2Waiter {
    TerminateChild,
}
