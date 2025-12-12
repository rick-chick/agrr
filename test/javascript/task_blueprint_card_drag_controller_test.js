/**
 * @jest-environment jsdom
 */

import TaskBlueprintCardDragController from "../../app/javascript/controllers/task_blueprint_card_drag_controller"
import { Application } from "@hotwired/stimulus"

const setupApplication = (element) => {
  const application = Application.start()
  element.setAttribute("data-controller", "task-blueprint-card-drag")
  application.register("task-blueprint-card-drag", TaskBlueprintCardDragController)
  return application
}

const dispatchTouchEvent = (target, type, touches, options = {}) => {
  const event = new Event(type, { bubbles: true, cancelable: true, ...options })
  Object.defineProperty(event, "touches", { value: touches, configurable: true })
  target.dispatchEvent(event)
  return event
}

describe("TaskBlueprintCardDragController touch interactions", () => {
  let element
  let card
  let canvas
  let application
  let controller

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="task-blueprint-card-drag">
        <div data-task-blueprint-card-drag-target="board"
             data-total-gdd="100"
             data-lane-count="3"
             id="task-schedule-blueprints-board"></div>
        <div data-task-blueprint-card-drag-target="canvas" id="task-board-canvas"></div>
        <div class="draggable-card"
             data-task-blueprint-card-drag-target="card"
             data-update-url="/task_schedule_blueprints/1"></div>
      </div>
    `
    element = document.querySelector("[data-controller='task-blueprint-card-drag']")
    card = element.querySelector("[data-task-blueprint-card-drag-target='card']")
    canvas = element.querySelector("[data-task-blueprint-card-drag-target='canvas']")

    jest.spyOn(window, "requestAnimationFrame").mockImplementation((cb) => cb())

    jest.spyOn(canvas, "getBoundingClientRect").mockReturnValue({
      left: 0,
      top: 0,
      right: 300,
      bottom: 300,
      width: 300,
      height: 300
    })
    jest.spyOn(card, "getBoundingClientRect").mockReturnValue({
      left: 50,
      top: 50,
      right: 130,
      bottom: 90,
      width: 80,
      height: 40
    })
    Object.defineProperty(card, "offsetWidth", { value: 80, configurable: true })
    Object.defineProperty(card, "offsetHeight", { value: 40, configurable: true })

    application = setupApplication(element)
    controller = application.getControllerForElementAndIdentifier(element, "task-blueprint-card-drag")
  })

  afterEach(() => {
    if (controller) {
      document.removeEventListener("touchmove", controller.handleTouchMove)
      document.removeEventListener("touchend", controller.handleTouchEnd)
    }
    if (application) {
      application.stop()
      application = null
    }
    controller = null
    document.body.innerHTML = ""
    jest.restoreAllMocks()
  })

  test("touchcancel後にスクロールがブロックされたままにならない", () => {
    dispatchTouchEvent(card, "touchstart", [{ clientX: 10, clientY: 10 }])
    dispatchTouchEvent(document, "touchmove", [{ clientX: 30, clientY: 30 }])

    const touchCancel = new Event("touchcancel", { bubbles: true, cancelable: true })
    document.dispatchEvent(touchCancel)

    const touchMove = new Event("touchmove", { bubbles: true, cancelable: true })
    touchMove.preventDefault = jest.fn()
    Object.defineProperty(touchMove, "touches", { value: [{ clientX: 50, clientY: 50 }], configurable: true })
    document.dispatchEvent(touchMove)

    expect(touchMove.preventDefault).not.toHaveBeenCalled()
    expect(card.classList.contains("card-dragging")).toBe(false)
  })
})
