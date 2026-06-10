//! ActionCable-compatible WebSocket (`/cable`).
//!
//! Ruby: `ApplicationCable`, `OptimizationChannel`, `PlansOptimizationChannel`, `FarmChannel`

use crate::state::AppState;
use agrr_adapters_sqlite::CultivationPlanSqliteGateway;
use agrr_domain::cultivation_plan::calculators::cultivation_plan_optimization_progress_calculator;
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use agrr_domain::cultivation_plan::mappers::to_port_payload;
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

fn optimization_snapshot_payload(
    plan_gateway: &CultivationPlanSqliteGateway,
    plan_id: i64,
) -> Option<Value> {
    let plan = plan_gateway.find_by_id(plan_id).ok()?;
    let status = plan.status.as_deref().unwrap_or("");

    if status == "completed" {
        let field_cultivations = plan_gateway.list_by_plan_id(plan_id).ok()?;
        if field_cultivations.is_empty()
            || !field_cultivations
                .iter()
                .all(|fc| fc.status.as_deref() == Some("completed"))
        {
            let message = plan.optimization_phase_message.as_deref();
            return Some(json!({
                "status": "failed",
                "progress": 0,
                "phase": plan.optimization_phase,
                "phase_message": message,
                "message": message
            }));
        }
        return Some(json!({
            "status": "completed",
            "progress": 100,
            "phase": "completed",
            "message_key": "models.cultivation_plan.phases.completed"
        }));
    }

    if status == "failed" {
        let message = plan.optimization_phase_message.as_deref();
        let message_key = message
            .filter(|m| m.starts_with("models.cultivation_plan.phase_failed."))
            .or(Some("models.cultivation_plan.phase_failed.default"));
        return Some(json!({
            "status": "failed",
            "progress": 0,
            "phase": "failed",
            "phase_message": message,
            "message": message,
            "message_key": message_key
        }));
    }

    if status == "pending" {
        return Some(json!({
            "status": "pending",
            "progress": 0,
            "phase": "scheduling",
            "message_key": "models.cultivation_plan.phases.initializing"
        }));
    }

    if status != "optimizing" {
        return None;
    }

    let field_cultivations = plan_gateway.list_by_plan_id(plan_id).ok()?;
    let progress =
        cultivation_plan_optimization_progress_calculator::progress_percent(&field_cultivations);
    let phase_message = plan.optimization_phase_message.as_deref();
    Some(to_port_payload(&plan, progress, phase_message))
}

async fn send_pong(socket: &mut WebSocket) -> bool {
    let pong = json!({ "type": "pong" });
    socket
        .send(Message::Text(pong.to_string().into()))
        .await
        .is_ok()
}

fn parse_plan_id_from_identifier(id_json: &Value) -> Option<i64> {
    let raw = id_json.get("cultivation_plan_id")?;
    raw.as_i64()
        .or_else(|| raw.as_str().and_then(|s| s.parse().ok()))
        .or_else(|| raw.as_f64().map(|f| f as i64))
}

async fn transmit_snapshot(
    socket: &mut WebSocket,
    identifier: &str,
    plan_gateway: &CultivationPlanSqliteGateway,
    plan_id: i64,
) -> bool {
    let Some(payload) = optimization_snapshot_payload(plan_gateway, plan_id) else {
        return true;
    };
    let message = json!({
        "identifier": identifier,
        "message": payload
    });
    socket
        .send(Message::Text(message.to_string().into()))
        .await
        .is_ok()
}

async fn cable_ws(ws: WebSocketUpgrade, State(state): State<AppState>) -> impl IntoResponse {
    let hub = state.cable_hub.clone();
    // actioncable-js は Sec-WebSocket-Protocol: actioncable-v1-json を送る。応答しないとハンドシェイク失敗。
    ws.protocols(["actioncable-v1-json"])
        .on_upgrade(move |socket| handle_socket(socket, hub, state))
}

async fn handle_socket(mut socket: WebSocket, hub: Arc<CableHub>, state: AppState) {
    // actioncable-js は welcome 受信後に subscribe を送る。未送信だと購読が開始されない。
    let welcome = json!({ "type": "welcome" });
    if socket
        .send(Message::Text(welcome.to_string().into()))
        .await
        .is_err()
    {
        return;
    }

    let plan_gateway = CultivationPlanSqliteGateway::new(state.sqlite.clone());
    while let Some(Ok(msg)) = socket.recv().await {
        let Message::Text(text) = msg else {
            continue;
        };
        let Ok(frame): Result<Value, _> = serde_json::from_str(&text) else {
            continue;
        };
        if frame.get("type").and_then(|t| t.as_str()) == Some("ping") {
            if !send_pong(&mut socket).await {
                return;
            }
            continue;
        }
        if frame.get("command").and_then(|c| c.as_str()) == Some("pong") {
            continue;
        }
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
        let plan_id = parse_plan_id_from_identifier(&id_json);
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
        if !transmit_snapshot(&mut socket, identifier, &plan_gateway, plan_id).await {
            return;
        }
        let mut rx = hub.subscribe_plan(plan_id).await;
        loop {
            tokio::select! {
                incoming = socket.recv() => {
                    match incoming {
                        None | Some(Err(_)) => return,
                        Some(Ok(Message::Close(_))) => return,
                        Some(Ok(Message::Text(text))) => {
                            if let Ok(frame) = serde_json::from_str::<Value>(&text) {
                                if frame.get("type").and_then(|t| t.as_str()) == Some("ping") {
                                    if !send_pong(&mut socket).await {
                                        return;
                                    }
                                }
                            }
                        }
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

#[cfg(test)]
mod cable_snapshot_tests {
    use super::*;
    use crate::test_support::test_pool_with_plan;

    #[test]
    fn pending_plan_returns_scheduling_snapshot() {
        let db = test_pool_with_plan(1);
        let gateway = CultivationPlanSqliteGateway::new(db.pool);
        let payload = optimization_snapshot_payload(&gateway, 1).expect("pending snapshot");
        assert_eq!(payload["status"], "pending");
        assert_eq!(payload["progress"], 0);
        assert_eq!(payload["phase"], "scheduling");
        assert_eq!(
            payload["message_key"],
            "models.cultivation_plan.phases.initializing"
        );
    }
}
