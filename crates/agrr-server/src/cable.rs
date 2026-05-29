//! ActionCable-compatible WebSocket (`/cable`).
//!
//! Ruby: `ApplicationCable`, `OptimizationChannel`, `PlansOptimizationChannel`, `FarmChannel`

use crate::state::AppState;
use agrr_adapters_sqlite::CultivationPlanSqliteGateway;
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::IntoResponse,
    routing::get,
    Router,
};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{broadcast, RwLock};

pub fn routes() -> Router<AppState> {
    Router::new().route("/cable", get(cable_ws))
}

type PlanStreams = Arc<RwLock<HashMap<i64, broadcast::Sender<String>>>>;

#[derive(Clone, Default)]
pub struct CableHub {
    plan_streams: PlanStreams,
}

impl CableHub {
    pub async fn subscribe_plan(&self, plan_id: i64) -> broadcast::Receiver<String> {
        let mut guard = self.plan_streams.write().await;
        let sender = guard.entry(plan_id).or_insert_with(|| {
            let (tx, _) = broadcast::channel(64);
            tx
        });
        sender.subscribe()
    }

    pub fn broadcast_plan(&self, plan_id: i64, message: Value) {
        let body = message.to_string();
        if let Ok(guard) = self.plan_streams.try_read() {
            if let Some(tx) = guard.get(&plan_id) {
                let _ = tx.send(body);
            }
        }
    }

    /// Alias for ActionCable optimization payloads (`status`, `progress`, `phase`, …).
    pub fn broadcast_plan_message(&self, plan_id: i64, message: Value) {
        self.broadcast_plan(plan_id, message);
    }
}

async fn cable_ws(ws: WebSocketUpgrade, State(state): State<AppState>) -> impl IntoResponse {
    let hub = state.cable_hub.clone();
    ws.on_upgrade(move |socket| handle_socket(socket, hub, state))
}

async fn handle_socket(mut socket: WebSocket, hub: Arc<CableHub>, state: AppState) {
    let plan_gateway = CultivationPlanSqliteGateway::new(state.sqlite.clone());
    while let Some(Ok(msg)) = socket.recv().await {
        let Message::Text(text) = msg else {
            continue;
        };
        let Ok(frame): Result<Value, _> = serde_json::from_str(&text) else {
            continue;
        };
        if frame.get("command").and_then(|c| c.as_str()) != Some("subscribe") {
            continue;
        }
        let identifier = frame
            .get("identifier")
            .and_then(|i| i.as_str())
            .unwrap_or("");
        let Ok(id_json): Result<Value, _> = serde_json::from_str(identifier) else {
            continue;
        };
        let channel = id_json.get("channel").and_then(|c| c.as_str()).unwrap_or("");
        let plan_id = id_json
            .get("cultivation_plan_id")
            .and_then(|v| v.as_i64());
        if channel != "OptimizationChannel" && channel != "PlansOptimizationChannel" {
            continue;
        }
        let Some(plan_id) = plan_id else {
            let reject = json!({
                "type": "reject_subscription",
                "identifier": identifier
            });
            let _ = socket.send(Message::Text(reject.to_string().into())).await;
            continue;
        };
        if plan_gateway.find_by_id(plan_id).is_err() {
            let reject = json!({
                "type": "reject_subscription",
                "identifier": identifier
            });
            let _ = socket.send(Message::Text(reject.to_string().into())).await;
            continue;
        }
        let confirm = json!({
            "type": "confirm_subscription",
            "identifier": identifier
        });
        if socket.send(Message::Text(confirm.to_string().into())).await.is_err() {
            return;
        }
        let mut rx = hub.subscribe_plan(plan_id).await;
        loop {
            tokio::select! {
                incoming = socket.recv() => {
                    match incoming {
                        None | Some(Err(_)) => return,
                        Some(Ok(Message::Close(_))) => return,
                        _ => {}
                    }
                }
                payload = rx.recv() => {
                    match payload {
                        Ok(body) => {
                            let message = json!({
                                "identifier": identifier,
                                "message": serde_json::from_str::<Value>(&body).unwrap_or(json!({}))
                            });
                            if socket.send(Message::Text(message.to_string().into())).await.is_err() {
                                return;
                            }
                        }
                        Err(_) => return,
                    }
                }
            }
        }
    }
}
