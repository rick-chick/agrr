/**
 * @jest-environment jsdom
 */

import TaskScheduleTimelineController from "../../app/javascript/controllers/task_schedule_timeline_controller"
import { Application } from "@hotwired/stimulus"

const buildController = (element, initialState = {}) => {
  const application = Application.start()
  application.register("task-schedule-timeline", TaskScheduleTimelineController)
  element.setAttribute("data-controller", "task-schedule-timeline")
  element.setAttribute("data-task-schedule-timeline-endpoint-value", "/plans/1/task_schedule.json")
  element.setAttribute(
    "data-task-schedule-timeline-initial-state-value",
    JSON.stringify(initialState)
  )
  element.setAttribute("data-task-schedule-timeline-loading-message-value", "読み込み中")
  element.setAttribute("data-task-schedule-timeline-error-message-value", "エラー")
  element.setAttribute("data-task-schedule-timeline-empty-message-value", "予定なし")
  element.setAttribute("data-task-schedule-timeline-items-endpoint-value", "/task_schedule_items")

  return application
}

const baseLabels = {
  empty_cell: "予定なし",
  unscheduled_title: "未確定",
  add_task: "予定追加",
  generated_label: "生成日時",
  detail: {
    title: "詳細",
    empty: "タスクを選択してください",
    statuses: {},
    actions: {
      reschedule: "日付を変更",
      reschedule_label: "新しい日付",
      updated: "更新しました",
      update_failed: "更新に失敗しました",
      date_required: "日付必須",
      submit: "保存",
      cancel_form: "閉じる"
    }
  }
}

describe("TaskScheduleTimelineController drag & drop", () => {
  let element
  let application
  let controller

  beforeEach(() => {
    document.body.innerHTML = `
      <div
        data-controller="task-schedule-timeline"
        data-task-schedule-timeline-endpoint-value=""
        data-task-schedule-timeline-initial-state-value="{}"
      >
        <div class="task-schedule-week-label" data-task-schedule-timeline-target="weekLabel"></div>
        <div data-task-schedule-timeline-target="minimap"></div>
        <div data-task-schedule-timeline-target="content"></div>
        <aside class="task-schedule-detail hidden" data-task-schedule-timeline-target="detailPanel">
          <h3 data-task-schedule-timeline-target="detailTitle"></h3>
          <dl data-task-schedule-timeline-target="detailList"></dl>
          <div data-task-schedule-timeline-target="detailActions"></div>
          <div data-task-schedule-timeline-target="detailForm"></div>
        </aside>
        <div class="timeline-modal" data-task-schedule-timeline-target="modal" aria-hidden="true">
          <div tabindex="-1" data-task-schedule-timeline-target="modalDialog"></div>
        </div>
      </div>
    `
    element = document.querySelector("[data-controller='task-schedule-timeline']")
  })

  afterEach(() => {
    if (application) {
      application.stop()
      application = null
    }
    document.body.innerHTML = ""
    jest.restoreAllMocks()
  })

  const setupController = (state) => {
    application = buildController(element, state)
    controller = application.getControllerForElementAndIdentifier(element, "task-schedule-timeline")
    return controller
  }

  const buildState = (overrides = {}) => {
    return {
      plan: { id: 1, name: "テスト計画", timeline_generated_at_display: "2025-11-01 09:00" },
      week: {
        start_date: "2025-11-03",
        end_date: "2025-11-09",
        label: "11/03 〜 11/09",
        days: [
          { date: "2025-11-03", weekday: "mon", is_today: false },
          { date: "2025-11-04", weekday: "tue", is_today: false }
        ]
      },
      fields: [
        {
          id: 1,
          field_cultivation_id: 1,
          name: "圃場A",
          crop_name: "トマト",
          area_sqm: 1200,
          schedules: {
            general: [
              {
                item_id: 101,
                name: "支柱設置",
                scheduled_date: "2025-11-03",
                category: "general",
                badge: { status: "planned" },
                details: {}
              }
            ],
            fertilizer: [],
            unscheduled: []
          }
        }
      ],
      labels: baseLabels,
      minimap: { weeks: [] },
      ...overrides
    }
  }

  test("ドラッグしたカードを別の日にドロップすると予定日を更新する", async () => {
    setupController(buildState())

    const taskElement = element.querySelector(".timeline-task")
    expect(taskElement).not.toBeNull()

    const patchSpy = jest.spyOn(controller, "patchItem").mockResolvedValue({})
    const refreshSpy = jest.spyOn(controller, "refreshCurrentWeek").mockResolvedValue()

    const dragStart = new Event("dragstart", { bubbles: true })
    dragStart.dataTransfer = { setData: jest.fn(), effectAllowed: "" }
    taskElement.dispatchEvent(dragStart)

    const dayCells = element.querySelectorAll(".timeline-day-cell")
    expect(dayCells.length).toBeGreaterThan(1)
    const targetCell = dayCells[1]

    const dragOver = new Event("dragover", { bubbles: true })
    dragOver.preventDefault = jest.fn()
    dragOver.dataTransfer = { dropEffect: "" }
    targetCell.dispatchEvent(dragOver)
    expect(targetCell.classList.contains("timeline-day-cell--drag-over")).toBe(true)

    const drop = new Event("drop", { bubbles: true })
    drop.preventDefault = jest.fn()
    drop.dataTransfer = { dropEffect: "" }
    targetCell.dispatchEvent(drop)

    await Promise.resolve()
    await Promise.resolve()

    expect(patchSpy).toHaveBeenCalledWith(101, {
      task_schedule_item: { scheduled_date: "2025-11-04" }
    })
    expect(refreshSpy).toHaveBeenCalled()
  })

  test("別圃場へのドロップは無視される", async () => {
    const state = buildState({
      fields: [
        {
          id: 1,
          field_cultivation_id: 1,
          name: "圃場A",
          crop_name: "トマト",
          area_sqm: 1200,
          schedules: {
            general: [
              {
                item_id: 101,
                name: "支柱設置",
                scheduled_date: "2025-11-03",
                category: "general",
                badge: { status: "planned" },
                details: {}
              }
            ],
            fertilizer: [],
            unscheduled: []
          }
        },
        {
          id: 2,
          field_cultivation_id: 2,
          name: "圃場B",
          crop_name: "きゅうり",
          area_sqm: 800,
          schedules: { general: [], fertilizer: [], unscheduled: [] }
        }
      ]
    })

    setupController(state)

    const taskElement = element.querySelector(".timeline-task")
    expect(taskElement).not.toBeNull()

    const patchSpy = jest.spyOn(controller, "patchItem").mockResolvedValue({})
    jest.spyOn(controller, "refreshCurrentWeek").mockResolvedValue()

    const dragStart = new Event("dragstart", { bubbles: true })
    dragStart.dataTransfer = { setData: jest.fn(), effectAllowed: "" }
    taskElement.dispatchEvent(dragStart)

    const otherFieldCell = element.querySelector(
      '.timeline-day-cell[data-field-id="2"][data-date="2025-11-04"]'
    )
    expect(otherFieldCell).not.toBeNull()

    const dragOver = new Event("dragover", { bubbles: true })
    dragOver.preventDefault = jest.fn()
    dragOver.dataTransfer = { dropEffect: "" }
    otherFieldCell.dispatchEvent(dragOver)
    expect(otherFieldCell.classList.contains("timeline-day-cell--drag-over")).toBe(false)

    const drop = new Event("drop", { bubbles: true })
    drop.preventDefault = jest.fn()
    drop.dataTransfer = { dropEffect: "" }
    otherFieldCell.dispatchEvent(drop)

    await Promise.resolve()
    await Promise.resolve()

    expect(patchSpy).not.toHaveBeenCalled()
  })
})


