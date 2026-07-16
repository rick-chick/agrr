/** Fixed tomato (jp) proposal used by contract tests — mirrors R4 valid_setup_proposal_body. */
export function tomatoJpSetupProposal() {
  return {
    stages: [
      {
        name: '育苗',
        order: 1,
        thermal_requirement: { required_gdd: '120' },
      },
    ],
    agricultural_tasks: [
      {
        ref: 'task-weeding',
        name: '除草',
        task_type: 'field_work',
        region: 'jp',
      },
    ],
    task_schedule_blueprints: [
      {
        agricultural_task_ref: 'task-weeding',
        stage_order: 1,
        stage_name: '育苗',
        gdd_trigger: 0,
        task_type: 'field_work',
        priority: 1,
      },
    ],
  };
}
