use crate::agricultural_task::interactors::task_schedule_ensure_blueprints_interactor::TaskScheduleEnsureBlueprintsInteractor;

#[test]
fn ensure_for_plan_is_noop_so_generation_fails_when_blueprints_missing() {
    let ensure = TaskScheduleEnsureBlueprintsInteractor::new();
    ensure.ensure_for_plan(1).expect("ensure");
}
