# i18n missing keys for Issue #13

Generated for GitHub Issue #13 on 2026-06-16.

## Commands

- `npm run check-hardcoded-i18n`
  - Added in this change as a report command.
  - Result: success, reporting `268` missing locale/key entries from `718` static translate references.
  - Scope: static `'<key>' | translate` and `translate.instant('<key>')` references under `frontend/src/app`, excluding unit specs.
  - Full local log: `tmp/issue-13-check-hardcoded-i18n.log` during the worker run.
- `bash .cursor/skills/test-common/scripts/run-test-frontend.sh --include='src/app/**/*catalog.spec.ts'`
  - Result before this report: GREEN.

`npm run check-hardcoded-i18n:enforce` is available for future gating once the known backlog is resolved.

## Scoped findings from `visual-review-results.md` P0/P1 candidates

### `entrySchedule.*`

Component references are present in:

- `src/app/components/entry-schedule/entry-schedule-list.component.ts`
- `src/app/components/entry-schedule/entry-schedule-detail.component.ts`

Missing from all locale files: `src/assets/i18n/ja.json`, `src/assets/i18n/en.json`, `src/assets/i18n/in.json`.

| Key |
| --- |
| `entrySchedule.title` |
| `entrySchedule.selectFarm` |
| `entrySchedule.loading` |
| `entrySchedule.retry` |
| `entrySchedule.noFarms` |
| `entrySchedule.show` |
| `entrySchedule.blockSelectFarm` |
| `entrySchedule.predictionFresh` |
| `entrySchedule.predictionUntil` |
| `entrySchedule.eligibleYes` |
| `entrySchedule.eligibleNo` |
| `entrySchedule.viz.ganttAria` |
| `entrySchedule.viz.listChartIntro` |
| `entrySchedule.viz.axisYear` |
| `entrySchedule.viz.sowBand` |
| `entrySchedule.viz.bandStartHint` |
| `entrySchedule.viz.transplantBand` |
| `entrySchedule.viz.monthTick` |
| `entrySchedule.viz.listChartFoot` |
| `entrySchedule.viz.noWindow` |
| `entrySchedule.collapse` |
| `entrySchedule.expand` |
| `entrySchedule.whyTitle` |
| `entrySchedule.table.detail` |
| `entrySchedule.loadMore` |
| `entrySchedule.listDisclaimer` |
| `entrySchedule.timeout` |
| `entrySchedule.error` |
| `entrySchedule.detailTitle` |
| `entrySchedule.back` |
| `entrySchedule.viz.ganttTitle` |
| `entrySchedule.viz.detailGanttIntro` |
| `entrySchedule.viz.detailGanttFoot` |
| `entrySchedule.windows` |
| `entrySchedule.phases` |
| `entrySchedule.timeline` |
| `entrySchedule.nextTask` |
| `entrySchedule.nextTaskPlaceholder` |
| `entrySchedule.stages` |

### `plans.task_schedules.*`

Component references are present in:

- `src/app/components/plans/plan-task-schedule.component.ts`
- `src/app/components/plans/task-schedule-timeline.component.ts`

Missing only from `src/assets/i18n/in.json`.

| Key |
| --- |
| `plans.task_schedules.title` |
| `plans.task_schedules.back_to_plan` |
| `plans.task_schedules.general_label` |
| `plans.task_schedules.fertilizer_label` |
| `plans.task_schedules.no_schedules` |

### `interaction_rules.*`

References are present in:

- `src/app/components/masters/interaction-rules/interaction-rule-list.component.ts`
- `src/app/components/masters/interaction-rules/interaction-rule-detail.component.ts`

Missing from all locale files: `src/assets/i18n/ja.json`, `src/assets/i18n/en.json`, `src/assets/i18n/in.json`.

| Key | Notes |
| --- | --- |
| `interaction_rules.form.rule_type_codes.continuous_cultivation` | Dynamic prefix from `ruleTypeLabel(code)`; `rule_type_continuous` exists but does not match the component lookup. |
| `interaction_rules.show.is_directional` | Detail view references this exact key; `interaction_rules.show.direction` exists but does not match. |

### `api.entry_schedule.*`

Server-side references are present in `crates/agrr-domain/src/public_plan/mappers/entry_schedule_crop_mapper.rs`.

Missing only from `src/assets/i18n/in.json`.

| Key |
| --- |
| `api.entry_schedule.label.sowing` |
| `api.entry_schedule.label.transplanting` |
| `api.entry_schedule.disclaimer.short` |
| `api.entry_schedule.reason.list` |
| `api.entry_schedule.reason.agrr` |
| `api.entry_schedule.reason.agrr_failed.generic` |
| `api.entry_schedule.reason.agrr_failed.daemon_unavailable` |
| `api.entry_schedule.reason.agrr_failed.execution_failed` |
| `api.entry_schedule.reason.agrr_failed.invalid_response` |
| `api.entry_schedule.reason.agrr_failed.insufficient_weather` |
| `api.entry_schedule.reason.agrr_failed.disabled` |
| `api.entry_schedule.reason.agrr_failed.crop_requirement_error` |

### Candidates checked but not catalog-missing

| Candidate | Result |
| --- | --- |
| `models.cultivation_plan.phases.completed` | Present in `ja`, `en`, and `in`. The visual issue should be handled as a runtime path/usage issue, not a missing catalog entry. |
| `pages.about.operator.contact_html` / `pages.about.operator.ads_notice_html` | Present in `ja`, `en`, and `in`. The P0 about finding is not a current missing-key finding for these exact keys. |

## Follow-up catalog spec policy

Add focused catalog specs with the fixing issue that owns each screen/namespace:

1. `entry-schedule-locale.catalog.spec.ts`
   - Assert all `entrySchedule.*` component keys for `ja`, `en`, and `in`.
   - Include nested `entrySchedule.viz.*` and `entrySchedule.table.detail`.
2. `plans-task-schedules-locale.catalog.spec.ts`
   - Assert the five `plans.task_schedules.*` keys for `ja`, `en`, and `in`.
   - This should be RED for `in` before Issue #14 fills the catalog.
3. `entry-schedule-api-locale.catalog.spec.ts`
   - Assert the `api.entry_schedule.*` keys used by `entry_schedule_crop_mapper.rs`.
   - This should be RED for `in` before Issue #15 fills the catalog.
4. `interaction-rules-locale.catalog.spec.ts`
   - Assert `interaction_rules.form.rule_type_codes.continuous_cultivation` and `interaction_rules.show.is_directional`.
   - This should be RED for all locales before the interaction-rules i18n issue fills the catalog.

Keep each spec scoped to the issue being implemented. Do not add one broad global i18n spec until the known backlog from `check-hardcoded-i18n` has been resolved, otherwise unrelated screens will make follow-up fixes hard to isolate.
