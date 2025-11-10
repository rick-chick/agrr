/**
 * @jest-environment jsdom
 */

import { Application } from "@hotwired/stimulus"
import TaskScheduleTimelineController from "../../app/javascript/controllers/task_schedule_timeline_controller"

const flushPromises = () =>
  new Promise((resolve) => {
    if (typeof setImmediate === "function") {
      setImmediate(resolve)
    } else {
      setTimeout(resolve, 0)
    }
  })

const originalFetch = global.fetch

const baseLabels = {
  detail: {
    title: "詳細",
    empty: "タスクを選択してください",
    actions: {
      confirm_cancel: "この予定をキャンセルしますか？",
      cancel_failed: "キャンセルに失敗しました",
      cancel: "予定をキャンセル"
    }
  }
}

const buildState = (overrides = {}) => ({
  plan: { id: 1, name: "テスト計画" },
  week: {
    start_date: "2025-11-03",
    end_date: "2025-11-09",
    label: "11/03 - 11/09",
    days: []
  },
  fields: [],
  labels: baseLabels,
  ...overrides
})

describe("TaskScheduleTimelineController undo integration", () => {
  let application
  let element
  let controller
  let originalConfirm

  beforeEach(async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({})
    })

    document.body.innerHTML = `
      <div
        data-controller="task-schedule-timeline"
        data-task-schedule-timeline-endpoint-value="/plans/1/task_schedule"
        data-task-schedule-timeline-initial-state-value='${JSON.stringify(buildState())}'
        data-task-schedule-timeline-loading-message-value="読み込み中"
        data-task-schedule-timeline-error-message-value="エラー"
        data-task-schedule-timeline-empty-message-value="予定はありません"
        data-task-schedule-timeline-items-endpoint-value="/plans/1/task_schedule_items"
      >
        <div data-task-schedule-timeline-target="content"></div>
        <div data-task-schedule-timeline-target="weekLabel"></div>
        <div data-task-schedule-timeline-target="generatedAt"></div>
        <aside data-task-schedule-timeline-target="detailPanel">
          <h3 data-task-schedule-timeline-target="detailTitle"></h3>
          <div data-task-schedule-timeline-target="detailList"></div>
          <div data-task-schedule-timeline-target="detailActions"></div>
          <div data-task-schedule-timeline-target="detailForm"></div>
        </aside>
        <div data-task-schedule-timeline-target="modal" aria-hidden="true">
          <div data-task-schedule-timeline-target="modalDialog" tabindex="-1"></div>
        </div>
      </div>
    `

    element = document.querySelector("[data-controller='task-schedule-timeline']")
    application = Application.start()
    application.register("task-schedule-timeline", TaskScheduleTimelineController)

    await flushPromises()

    controller = application.getControllerForElementAndIdentifier(element, "task-schedule-timeline")

    const taskElement = document.createElement("button")
    taskElement.id = "task_schedule_item_42"
    taskElement.dataset.undoDeleteRecord = "true"
    taskElement.className = "timeline-task"
    element.querySelector("[data-task-schedule-timeline-target='content']").appendChild(taskElement)

    originalConfirm = window.confirm
    window.confirm = jest.fn().mockReturnValue(true)
  })

  afterEach(() => {
    if (application) {
      application.stop()
      application = null
    }
    document.body.innerHTML = ""
    window.confirm = originalConfirm
    jest.restoreAllMocks()
    global.fetch = originalFetch
  })

  test("cancelTask が undo:show イベントをディスパッチする", async () => {
    const undoResponse = {
      undo_token: "token-123",
      undo_path: "/undo/token-123",
      toast_message: "削除を取り消しますか？",
      undo_deadline: "2025-11-09T12:00:00Z",
      auto_hide_after: 5000,
      resource_dom_id: "task_schedule_item_42",
      resource: "潅水",
      redirect_path: "/plans/1"
    }

    const deleteMock = jest.spyOn(controller, "deleteItem").mockResolvedValue(undoResponse)
    const refreshMock = jest.spyOn(controller, "refreshCurrentWeek").mockResolvedValue()
    jest.spyOn(controller, "resetDetailPanel").mockImplementation(() => {})

      controller.currentDetail = { item_id: 42, dom_id: "task_schedule_item_42", name: "潅水" }

    const undoShowListener = jest.fn()
    window.addEventListener("undo:show", undoShowListener, { once: true })

    const event = { preventDefault: jest.fn() }
    await controller.cancelTask(event)

    expect(event.preventDefault).toHaveBeenCalled()
    expect(window.confirm).toHaveBeenCalled()
    expect(deleteMock).toHaveBeenCalledWith(42)
    expect(undoShowListener).toHaveBeenCalledTimes(1)

    const dispatchedEvent = undoShowListener.mock.calls[0][0]
    expect(dispatchedEvent).toBeInstanceOf(CustomEvent)
    expect(dispatchedEvent.type).toBe("undo:show")
    expect(dispatchedEvent.detail).toEqual(expect.objectContaining(undoResponse))
    expect(refreshMock).toHaveBeenCalled()

    const taskElement = document.getElementById("task_schedule_item_42")
    expect(taskElement).not.toBeNull()
    expect(taskElement.classList.contains("undo-delete--hidden")).toBe(true)
    expect(taskElement?.dataset?.undoDeleteToken).toBe(undoResponse.undo_token)
  })

  test("undo:restored イベントで refreshCurrentWeek が呼び出される", async () => {
    const refreshMock = jest.spyOn(controller, "refreshCurrentWeek").mockResolvedValue()
    jest.spyOn(controller, "resetDetailPanel").mockImplementation(() => {})

    window.dispatchEvent(new CustomEvent("undo:restored", { detail: { undo_token: "token-999" } }))
    await flushPromises()

    expect(refreshMock).toHaveBeenCalled()
  })
})

