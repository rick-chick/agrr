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

  return application
}

describe("TaskScheduleTimelineController detail panel", () => {
  let element

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
        </aside>
      </div>
    `
    element = document.querySelector("[data-controller='task-schedule-timeline']")
  })

  test("shows detail panel with task information when task is clicked", () => {
    const initialState = {
      plan: { id: 1, name: "テスト", timeline_generated_at_display: "2025-11-01 09:00" },
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
          name: "圃場A",
          schedules: {
            general: [
              {
                item_id: 1,
                name: "除草",
                scheduled_date: "2025-11-03",
                category: "general",
                badge: { type: "field_work", priority_level: "priority-medium", status: "planned" },
                details: {
                  stage: { name: "初期管理", order: 1 },
                  gdd: { trigger: "120.0", tolerance: "10.0" },
                  priority: 2,
                  weather_dependency: "no_rain_24h",
                  time_per_sqm: "0.75",
                  master: {
                    name: "除草作業",
                    description: "雑草を取り除く",
                    required_tools: ["ホー"],
                    skill_level: "beginner"
                  }
                }
              }
            ],
            fertilizer: [],
            unscheduled: []
          }
        }
      ],
      labels: {
        empty_cell: "予定なし",
        unscheduled_title: "未確定の作業",
        generated_label: "生成日時"
      },
      minimap: {
        start_date: "2025-10-27",
        end_date: "2025-12-01",
        weeks: [
          { start_date: "2025-11-03", label: "11/03", task_count: 1, density: "low", month_key: "2025-11" },
          { start_date: "2025-11-10", label: "11/10", task_count: 3, density: "medium", month_key: "2025-11" }
        ]
      }
    }

    buildController(element, initialState)

    const event = new Event("click")
    const taskElement = element.querySelector(".timeline-task")
    expect(taskElement).not.toBeNull()

    taskElement.dispatchEvent(event)

    const detailPanel = element.querySelector("[data-task-schedule-timeline-target='detailPanel']")
    expect(detailPanel.classList.contains("hidden")).toBe(false)

    const title = element.querySelector("[data-task-schedule-timeline-target='detailTitle']")
    expect(title.textContent).toContain("除草")

    const detailList = element.querySelector("[data-task-schedule-timeline-target='detailList']")
    expect(detailList.textContent).toContain("初期管理")
    expect(detailList.textContent).toContain("優先度: 中")
    expect(detailList.textContent).toContain("天候条件: no_rain_24h")
    expect(detailList.textContent).toContain("作業マスタ: 除草作業")
    expect(detailList.textContent).toContain("作業説明: 雑草を取り除く")
    expect(detailList.textContent).toContain("必要な工具: ホー")
    expect(detailList.textContent).toContain("推奨スキル: 初級")
  })

  test("renders minimap weeks", () => {
    const initialState = {
      week: {
        start_date: "2025-11-03",
        end_date: "2025-11-09",
        label: "11/03 〜 11/09",
        days: []
      },
      fields: [],
      labels: {},
      minimap: {
        start_date: "2025-10-27",
        end_date: "2025-11-24",
        weeks: [
          { start_date: "2025-10-27", label: "10/27", task_count: 1, density: "low", month_key: "2025-10" },
          { start_date: "2025-11-03", label: "11/03", task_count: 4, density: "medium", month_key: "2025-11" }
        ]
      }
    }

    buildController(element, initialState)

    const minimapButtons = element.querySelectorAll(".timeline-minimap__week")
    expect(minimapButtons.length).toBe(2)
    expect(minimapButtons[1].classList.contains("is-active")).toBe(true)
    expect(minimapButtons[1].classList.contains("timeline-minimap__week--density-medium")).toBe(true)
    expect(minimapButtons[1].dataset.density).toBe("medium")
    expect(minimapButtons[1].textContent).toBe("11/03")

    const labels = element.querySelectorAll(".timeline-minimap__label")
    expect(labels.length).toBe(2)
    expect(labels[0].textContent).toBe("2025/10")
    expect(labels[1].textContent).toBe("2025/11")
  })
})


