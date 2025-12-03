/**
 * @jest-environment jsdom
 */

import { Application } from "@hotwired/stimulus"
import PlansShowController from "../../app/javascript/controllers/plans_show_controller"

const flushPromises = () =>
  new Promise((resolve) => {
    if (typeof setImmediate === "function") {
      setImmediate(resolve)
    } else {
      setTimeout(resolve, 0)
    }
  })

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

describe("PlansShowController", () => {
  let application

  beforeEach(() => {
    // グローバル関数のモック
    window.prepareGanttData = jest.fn((data) => ({
      fields: data.fields || [],
      cultivations: data.cultivations || []
    }))
    window.setGanttDataAttributes = jest.fn()
    window.initCustomGanttChart = jest.fn()
    window.cleanupGanttChart = jest.fn()

    global.fetch = jest.fn()

    document.body.innerHTML = ""
    application = Application.start()
    application.register("plans-show", PlansShowController)
  })

  afterEach(() => {
    application?.stop()
    document.body.innerHTML = ""
    global.fetch.mockReset()
    delete window.prepareGanttData
    delete window.setGanttDataAttributes
    delete window.initCustomGanttChart
    delete window.cleanupGanttChart
  })

  test("connect時にデータを取得してガントチャートを初期化する", async () => {
    document.body.innerHTML = `
      <div data-controller="plans-show">
        <div id="gantt-chart-container"
             data-cultivation-plan-id="1"
             data-data-url="/api/v1/plans/1/data">
        </div>
      </div>
    `

    const mockData = {
      success: true,
      data: {
        fields: [{ id: 1, name: "圃場1" }],
        cultivations: [{ id: 1, field_id: 1 }]
      }
    }

    global.fetch.mockResolvedValue({
      ok: true,
      json: jest.fn().mockResolvedValue(mockData)
    })

    // Stimulusのconnectが完了してリスナーが登録されるのを待つ
    await flushPromises()
    document.dispatchEvent(new Event("turbo:load"))
    await flushPromises()
    await flushPromises()

    expect(global.fetch).toHaveBeenCalledWith("/api/v1/plans/1/data")
    expect(window.prepareGanttData).toHaveBeenCalledWith(mockData.data)
    expect(window.setGanttDataAttributes).toHaveBeenCalled()
    expect(window.initCustomGanttChart).toHaveBeenCalled()
  })

  test("レガシーJSが読み込まれていない場合はポーリング後にエラーを表示する", async () => {
    // initCustomGanttChart を一旦未定義にして、読み込み失敗ケースを再現
    delete window.initCustomGanttChart

    document.body.innerHTML = `
      <div data-controller="plans-show">
        <div id="gantt-chart-container"
             data-cultivation-plan-id="1"
             data-data-url="/api/v1/plans/1/data">
        </div>
      </div>
    `

    const mockData = {
      success: true,
      data: {
        fields: [{ id: 1, name: "圃場1" }],
        cultivations: [{ id: 1, field_id: 1 }]
      }
    }

    global.fetch.mockResolvedValue({
      ok: true,
      json: jest.fn().mockResolvedValue(mockData)
    })

    // Stimulusのconnectが完了してリスナーが登録されるのを待つ
    await flushPromises()
    document.dispatchEvent(new Event("turbo:load"))

    // fetch -> JSON パース -> waitForGanttScripts のポーリングを進める（実時間で待機）
    await flushPromises()
    await sleep(1200)
    await flushPromises()

    const container = document.getElementById("gantt-chart-container")
    expect(container.innerHTML).toContain("ガントチャート機能が読み込まれていません")
    // タイムアウト時はレガシー関数が未定義のままであることを確認
    expect(window.initCustomGanttChart).toBeUndefined()
  })

  test("レガシーJS読み込みがタイムアウトした後でも、後続イベントで再初期化される", async () => {
    // 初回はレガシーJSが未読み込みの状態を再現
    delete window.prepareGanttData
    delete window.setGanttDataAttributes
    delete window.initCustomGanttChart

    document.body.innerHTML = `
      <div data-controller="plans-show">
        <div id="gantt-chart-container"
             data-cultivation-plan-id="1"
             data-data-url="/api/v1/plans/1/data">
        </div>
      </div>
    `

    const mockData = {
      success: true,
      data: {
        fields: [{ id: 1, name: "圃場1" }],
        cultivations: [{ id: 1, field_id: 1 }]
      }
    }

    global.fetch.mockResolvedValue({
      ok: true,
      json: jest.fn().mockResolvedValue(mockData)
    })

    // Stimulusのconnectが完了してリスナーが登録されるのを待つ
    await flushPromises()

    // 初回 turbo:load で waitForGanttScripts がタイムアウトするケース
    document.dispatchEvent(new Event("turbo:load"))

    await sleep(1200)
    await flushPromises()

    const container = document.getElementById("gantt-chart-container")
    expect(container.innerHTML).toContain("ガントチャート機能が読み込まれていません")

    // 後続でレガシーJSが読み込まれた状態を再現
    window.prepareGanttData = jest.fn((data) => ({
      fields: data.fields || [],
      cultivations: data.cultivations || []
    }))
    window.setGanttDataAttributes = jest.fn()
    window.initCustomGanttChart = jest.fn()

    // 再度 turbo:load が発火した場合に、再初期化されることを確認
    document.dispatchEvent(new Event("turbo:load"))

    await flushPromises()
    await flushPromises()

    expect(window.initCustomGanttChart).toHaveBeenCalled()
  })

  test("データ取得に失敗した場合エラーを表示する", async () => {
    document.body.innerHTML = `
      <div data-controller="plans-show">
        <div id="gantt-chart-container"
             data-cultivation-plan-id="1"
             data-data-url="/api/v1/plans/1/data">
        </div>
      </div>
    `

    global.fetch.mockRejectedValue(new Error("Network error"))

    // Stimulusのconnectが完了してリスナーが登録されるのを待つ
    await flushPromises()
    document.dispatchEvent(new Event("turbo:load"))
    await flushPromises()
    await flushPromises()

    const container = document.getElementById("gantt-chart-container")
    expect(container.innerHTML).toContain("データの読み込みに失敗しました")
    expect(window.initCustomGanttChart).not.toHaveBeenCalled()
  })

  test("planIdまたはdataUrlが欠落している場合エラーを表示する", async () => {
    document.body.innerHTML = `
      <div data-controller="plans-show">
        <div id="gantt-chart-container">
        </div>
      </div>
    `

    // Stimulusのconnectが完了してリスナーが登録されるのを待つ
    await flushPromises()
    document.dispatchEvent(new Event("turbo:load"))
    await flushPromises()

    const container = document.getElementById("gantt-chart-container")
    expect(container.innerHTML).toContain("データの読み込みに必要な情報が不足しています")
    expect(global.fetch).not.toHaveBeenCalled()
  })

  test("disconnect時にcleanupGanttChartを呼び出す", async () => {
    document.body.innerHTML = `
      <div data-controller="plans-show">
        <div id="gantt-chart-container"></div>
      </div>
    `

    const element = document.querySelector("[data-controller='plans-show']")
    await flushPromises()
    const controller = application.getControllerForElementAndIdentifier(element, "plans-show")

    controller.disconnect()

    expect(window.cleanupGanttChart).toHaveBeenCalled()
  })

  test("gantt-chart-containerが存在しない場合は何もしない", async () => {
    document.body.innerHTML = `
      <div data-controller="plans-show">
      </div>
    `

    // Stimulusのconnectが完了してリスナーが登録されるのを待つ
    await flushPromises()
    document.dispatchEvent(new Event("turbo:load"))
    await flushPromises()

    expect(global.fetch).not.toHaveBeenCalled()
  })
})

