# ADR 0010: `Domain::ApiWeather` naming is not HTTP-channel vocabulary

- **Status**: Accepted
- **Date**: 2026-05-08

## Context

[`ARCHITECTURE.md`](../../ARCHITECTURE.md) **Prohibited practices → Interactors** item **4** forbids encoding **delivery channel or presentation shape** in interactor, gateway interface, or cross-port DTO **names** (examples include `Html`, `Json`, `Page`, and REST-channel prefixes such as `ApiV1` on domain types).

The codebase has a bounded context under [`lib/domain/api_weather/`](../../lib/domain/api_weather/) with module `Domain::ApiWeather` and types such as `ApiWeatherForecastInteractor`, `ApiWeatherFailureDto`, and `AgrrServiceWeatherQueryGateway`. The substring `Api` here denotes **integration with the external agrr weather query protocol / daemon** (JSON-over-command), not “this object exists because of our Rails `Api::` HTTP controllers.”

Mechanical grep hits on `Api*` are therefore ambiguous without meaning review.

## Decision

- Treat **`Domain::ApiWeather::*`** as a **bounded context name** (external weather service integration), **not** as naming our HTTP API surface.
- **No rename** of this BC solely to strip `Api`: the cost across adapters, presenters, composition root, and tests would be high; the gain would be naming purity without reducing real coupling.
- If a future redesign splits “weather daemon client” from other concerns, prefer new names that describe **integration mechanism** (e.g. daemon, service query) without implying Rails routing — but that is out of scope unless the use case changes.

## Consequences

- CA backlog and scans may **exclude** `Domain::ApiWeather` from “channel-shaped `Api` / `ApiV1` domain type” remediation lists, with this ADR as the recorded rationale.
- Presenters under `Presenters::Api::Weather::*` remain HTTP-edge formatting; they do not justify renaming the domain BC.

## Alternatives considered

- **Mass rename** (e.g. `Domain::WeatherService::*`) — deferred: large churn, same behavioral boundary.
- **Rename only interactors** — rejected: would split BC naming and worsen grep/consistency without clearing the module prefix.
