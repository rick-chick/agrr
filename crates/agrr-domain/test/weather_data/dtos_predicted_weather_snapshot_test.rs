// Tests for `dtos/predicted_weather_snapshot.rs` (Ruby parity under test/domain/weather_data/).

    use serde_json::json;

    #[test]
    fn from_document_deep_copies_nested_hash() {
        let dto = PredictedWeatherSnapshot::from_document(Some(json!({ "a": { "b": 1 } })))
            .expect("valid");
        let doc = dto.document().expect("document");
        assert_eq!(doc["a"]["b"], 1);
    }

    #[test]
    fn to_storage_hash_returns_mutable_deep_dup() {
        let dto =
            PredictedWeatherSnapshot::from_document(Some(json!({ "x": [ { "y": 2 } ] })))
                .expect("valid");
        let mut h = dto.to_storage_hash().expect("hash");
        h["x"][0]["y"] = json!(99);
        assert_eq!(dto.document().expect("doc")["x"][0]["y"], 2);
    }

    #[test]
    fn storage_column_value_accepts_dto_or_nil() {
        assert!(PredictedWeatherSnapshot::storage_column_value(None)
            .expect("ok")
            .is_none());
        let dto = PredictedWeatherSnapshot::from_document(Some(json!({ "k": "v" })))
            .expect("valid");
        let stored = PredictedWeatherSnapshot::storage_column_value(Some(
            PredictedWeatherSnapshotInput::Dto(dto),
        ))
        .expect("ok");
        assert_eq!(stored, Some(json!({ "k": "v" })));
    }
