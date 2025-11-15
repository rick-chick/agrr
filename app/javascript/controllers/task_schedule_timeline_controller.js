import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="task-schedule-timeline"
export default class extends Controller {
  static targets = [
    "content",
    "weekLabel",
    "generatedAt",
    "detailPanel",
    "detailTitle",
    "detailList",
    "detailActions",
    "detailForm",
    "minimap",
    "modal",
    "modalDialog"
  ]

  static values = {
    endpoint: String,
    initialState: Object,
    loadingMessage: String,
    errorMessage: String,
    emptyMessage: String,
    unknownMessage: String,
    itemsEndpoint: String
  }

  connect() {
    this.state = this.initialStateValue || null
    this.currentDetail = null
    this.currentCreateField = null
    this.formMessageTimer = null
    this.previousFocus = null
    this.draggedTask = null
    this.draggedElement = null
    this.dragActiveCell = null
    this.dragPendingCell = null
    this.dragErrorTimer = null
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleUndoRestored = this.handleUndoRestored.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    window.addEventListener("undo:restored", this.handleUndoRestored)
    this.render()
  }

  disconnect() {
    if (this._abortController) {
      this._abortController.abort()
    }
    if (this.formMessageTimer) {
      clearTimeout(this.formMessageTimer)
      this.formMessageTimer = null
    }
    if (this.dragErrorTimer) {
      clearTimeout(this.dragErrorTimer)
      this.dragErrorTimer = null
    }
    this.clearDragState()
    this.hideModal()
    document.removeEventListener("keydown", this.handleKeydown)
    window.removeEventListener("undo:restored", this.handleUndoRestored)
  }

  prevWeek() {
    this.shiftWeek(-7)
  }

  nextWeek() {
    this.shiftWeek(7)
  }

  today() {
    const today = new Date()
    const monday = this.beginningOfWeek(today)
    this.loadWeek(this.formatDateISO(monday))
  }

  shiftWeek(days) {
    if (!this.state || !this.state.week) return

    const currentStart = new Date(this.state.week.start_date)
    currentStart.setDate(currentStart.getDate() + days)
    const weekStartIso = this.formatDateISO(this.beginningOfWeek(currentStart))
    this.loadWeek(weekStartIso)
  }

  loadWeek(weekStartIso, options = {}) {
    const url = new URL(this.endpointValue, window.location.origin)
    url.searchParams.set("week_start", weekStartIso)

    if (options.showLoading !== false) {
      this.showLoading()
    }

    if (this._abortController) {
      this._abortController.abort()
    }
    this._abortController = new AbortController()

    return fetch(url.toString(), {
      headers: { Accept: "application/json" },
      signal: this._abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error("Network response was not ok")
        return response.json()
      })
      .then((data) => {
        this.state = data
        this.render()
      })
      .catch((error) => {
        if (error.name === "AbortError") return
        this.showError()
        console.error("[TaskScheduleTimeline] fetch error", error)
      })
  }

  render() {
    if (!this.hasContentTarget) return

    if (!this.state) {
      this.showLoading()
      return
    }

    this.updateWeekLabel()
    this.updateGeneratedAt()
    this.resetDetailPanel()
    this.renderMinimap()

    const fields = this.state.fields || []
    if (fields.length === 0) {
      this.contentTarget.innerHTML = `<div class="task-schedule-empty">${this.escapeHtml(
        this.emptyMessageValue || ""
      )}</div>`
      return
    }

    const weekDays = this.state.week?.days || []

    const html = fields.map((field) => this.renderFieldBlock(field, weekDays)).join("")

    this.contentTarget.innerHTML = html
  }

  resetDetailPanel() {
    this.resetDetailContent()
    this.hideModal()
  }

  resetDetailContent() {
    if (!this.hasDetailPanelTarget) return

    if (this.hasDetailTitleTarget) this.detailTitleTarget.textContent = this.detailLabels().title || ""
    if (this.hasDetailListTarget) {
      this.detailListTarget.innerHTML = `<div class="detail-row detail-row--empty">${this.escapeHtml(
        this.detailLabels().empty
      )}</div>`
    }
    if (this.hasDetailActionsTarget) {
      this.detailActionsTarget.innerHTML = ""
    }
    if (this.hasDetailFormTarget) {
      this.detailFormTarget.innerHTML = ""
    }
    this.currentDetail = null
    this.currentCreateField = null
  }

  renderFieldBlock(field, weekDays) {
    const taskOptionsPayload = this.encodeDataset(field.task_options || [])
    const defaultCropId = field.crop_id != null ? String(field.crop_id) : ""
    const defaultCropName = field.crop_name || ""

    const addButton = `
      <button type="button"
              class="task-schedule-field__add"
              data-action="task-schedule-timeline#openCreateForm"
              data-field-id="${field.field_cultivation_id}"
              data-field-name="${this.escapeHtml(field.name || "")}"
              data-crop-id="${defaultCropId}"
              data-crop-name="${this.escapeHtml(defaultCropName)}"
              data-task-options="${taskOptionsPayload}">
        ＋ ${this.escapeHtml(this.addTaskLabel())}
      </button>
    `

    const fieldHeader = `
      <header class="task-schedule-field__header">
        <div class="task-schedule-field__name">${this.escapeHtml(field.name || "")}</div>
        <div class="task-schedule-field__subtitle">
          ${this.renderFieldSubtitle(field)}
        </div>
        <div class="task-schedule-field__actions">
          ${addButton}
        </div>
      </header>
    `

    const grid = this.renderTimelineGrid(field, weekDays)
    const unscheduled = this.renderUnscheduled(field)

    return `<section class="task-schedule-field">${fieldHeader}${grid}${unscheduled}</section>`
  }

  renderFieldSubtitle(field) {
    const crop = field.crop_name || "-"
    const area = field.area_sqm ? `${this.formatNumber(field.area_sqm)}㎡` : "–"
    return this.escapeHtml(`${crop} / ${area}`)
  }

  renderTimelineGrid(field, weekDays) {
    if (!weekDays.length) return ""

    const headerRow = weekDays
      .map((day) => {
        const date = new Date(day.date)
        const label = `${date.getMonth() + 1}/${date.getDate()} (${this.weekdayLabel(date)})`
        const todayClass = day.is_today ? " timeline-day-label--today" : ""
        return `<div class="timeline-day-label${todayClass}">${this.escapeHtml(label)}</div>`
      })
      .join("")

    const tasksByDate = this.buildTasksByDate(field)

    const taskRows = weekDays
      .map((day) => this.renderDayCell(field, day, tasksByDate.get(day.date) || []))
      .join("")

    return `
      <div class="timeline-grid">
        <div class="timeline-day-header-row">${headerRow}</div>
        <div class="timeline-day-cells">${taskRows}</div>
      </div>
    `
  }

  renderDayCell(field, day, tasks) {
    const classes = ["timeline-day-cell"]
    let content = ""

    if (!tasks.length) {
      classes.push("timeline-day-cell--empty")
      content = this.escapeHtml(this.emptyCellLabel())
    } else {
      content = tasks.map((task) => this.renderTask(task, field)).join("")
    }

    const attrs = [`class="${classes.join(" ")}"`]
    if (day?.date) {
      attrs.push(`data-date="${day.date}"`)
    }
    if (field?.field_cultivation_id != null) {
      attrs.push(`data-field-id="${field.field_cultivation_id}"`)
    }

    attrs.push(
      `data-action="dragenter->task-schedule-timeline#allowDrop dragover->task-schedule-timeline#allowDrop dragleave->task-schedule-timeline#leaveDropZone drop->task-schedule-timeline#dropTask"`
    )

    return `<div ${attrs.join(" ")}>${content}</div>`
  }

  renderTask(task, field) {
    const classes = ["timeline-task"]
    classes.push(task.category === "fertilizer" ? "timeline-task--fertilizer" : "timeline-task--general")

    if (task.badge?.status) classes.push(`timeline-task--status-${task.badge.status}`)

    const domId = this.taskDomId(task)
    const detailPayload = this.encodeDetailPayload(task)
    const actions = [
      "task-schedule-timeline#showDetails",
      "dragstart->task-schedule-timeline#startDrag",
      "dragend->task-schedule-timeline#endDrag"
    ]

    const attributes = [
      'type="button"',
      `class="${classes.join(" ")}"`,
      `data-detail="${detailPayload}"`,
      `data-field-id="${field.field_cultivation_id}"`,
      `data-item-id="${task.item_id}"`,
      `data-category="${task.category}"`,
      `data-scheduled-date="${task.scheduled_date || ""}"`,
      'draggable="true"',
      `data-action="${actions.join(" ")}"`,
      'data-undo-delete-record="true"'
    ]

    if (domId) {
      attributes.unshift(`id="${this.escapeHtml(domId)}"`)
      attributes.push(`data-dom-id="${this.escapeHtml(domId)}"`)
    }

    return `
        <button ${attributes.join(" ")}>
        <span class="timeline-task__name">${this.escapeHtml(task.name)}</span>
      </button>
    `
  }

  startDrag(event) {
    const button = event.currentTarget
    if (!(button instanceof HTMLElement)) return

    const itemId = Number(button.dataset.itemId)
    const fieldId = button.dataset.fieldId
    if (!itemId || !fieldId) return

    const scheduledDate = button.dataset.scheduledDate || ""

    this.draggedTask = { itemId, fieldId, scheduledDate }
    this.draggedElement = button
    button.classList.add("timeline-task--dragging")

    if (event.dataTransfer) {
      try {
        event.dataTransfer.setData("application/json", JSON.stringify(this.draggedTask))
      } catch (error) {
        console.warn("[TaskScheduleTimeline] failed to attach drag payload", error)
      }
      event.dataTransfer.effectAllowed = "move"
    }
  }

  endDrag() {
    this.clearDragState()
  }

  allowDrop(event) {
    if (!this.draggedTask) return
    const cell = event.currentTarget
    if (!(cell instanceof HTMLElement)) return

    if (this.canDropOnCell(cell)) {
      event.preventDefault()
      if (event.dataTransfer) {
        event.dataTransfer.dropEffect = "move"
      }
      this.highlightDropCell(cell)
    } else {
      this.removeDropHighlight(cell)
    }
  }

  leaveDropZone(event) {
    const cell = event.currentTarget
    if (!(cell instanceof HTMLElement)) return
    this.removeDropHighlight(cell)
  }

  async dropTask(event) {
    if (!this.draggedTask) return
    const cell = event.currentTarget
    if (!(cell instanceof HTMLElement)) return

    event.preventDefault()

    if (!this.canDropOnCell(cell)) {
      this.clearDragState()
      return
    }

    const targetDate = cell.dataset.date
    if (!targetDate || targetDate === this.draggedTask.scheduledDate) {
      this.clearDragState()
      return
    }

    this.removeDropHighlight(cell)

    try {
      await this.patchItem(this.draggedTask.itemId, {
        task_schedule_item: { scheduled_date: targetDate }
      })
      await this.refreshCurrentWeek({ showLoading: false })
    } catch (error) {
      this.showDragDropError()
      console.error("[TaskScheduleTimeline] drag & drop update failed", error)
    } finally {
      this.clearDragState()
    }
  }

  canDropOnCell(cell) {
    if (!this.draggedTask) return false
    if (!(cell instanceof HTMLElement)) return false
    const fieldId = cell.dataset.fieldId
    const date = cell.dataset.date
    if (!fieldId || !date) return false
    return fieldId === String(this.draggedTask.fieldId)
  }

  highlightDropCell(cell) {
    if (this.dragActiveCell === cell) return
    this.clearAllDropHighlights()
    cell.classList.add("timeline-day-cell--drag-over")
    this.dragActiveCell = cell
  }

  removeDropHighlight(cell) {
    if (!(cell instanceof HTMLElement)) return
    cell.classList.remove("timeline-day-cell--drag-over")
    if (this.dragActiveCell === cell) {
      this.dragActiveCell = null
    }
  }

  clearAllDropHighlights() {
    if (!this.element) return
    this.element.querySelectorAll(".timeline-day-cell--drag-over").forEach((el) => {
      el.classList.remove("timeline-day-cell--drag-over")
    })
    this.dragActiveCell = null
  }

  markCellPending(cell, pending) {
    if (!(cell instanceof HTMLElement)) return
    if (pending) {
      cell.classList.add("timeline-day-cell--pending")
      this.dragPendingCell = cell
    } else {
      cell.classList.remove("timeline-day-cell--pending")
      if (this.dragPendingCell === cell) {
        this.dragPendingCell = null
      }
    }
  }

  showDragDropError() {
    const message = this.detailLabels().actions?.update_failed || "更新に失敗しました"
    if (!this.element) return

    let container = this.element.querySelector(".timeline-drag-error")
    if (!container) {
      container = document.createElement("div")
      container.className = "timeline-drag-error"
      this.element.insertBefore(container, this.element.firstChild)
    }
    container.textContent = message
    container.classList.add("is-visible")

    if (this.dragErrorTimer) {
      clearTimeout(this.dragErrorTimer)
    }
    this.dragErrorTimer = setTimeout(() => {
      container?.classList.remove("is-visible")
      this.dragErrorTimer = null
    }, 4000)
  }

  clearDragState() {
    if (this.draggedElement) {
      this.draggedElement.classList.remove("timeline-task--dragging")
      this.draggedElement = null
    }
    this.draggedTask = null
    this.clearAllDropHighlights()
    if (this.dragPendingCell) {
      this.dragPendingCell.classList.remove("timeline-day-cell--pending")
      this.dragPendingCell = null
    }
  }

  renderMinimap() {
    if (!this.hasMinimapTarget || !this.state?.minimap) return

    const { weeks } = this.state.minimap
    if (!weeks || weeks.length === 0) {
      this.minimapTarget.innerHTML = ""
      return
    }

    const fragment = document.createDocumentFragment()
    let lastMonthKey = null

    weeks.forEach((week) => {
      const monthKey = week.month_key
      if (monthKey && monthKey !== lastMonthKey) {
        const label = document.createElement("div")
        label.className = "timeline-minimap__label"
        const [year, month] = monthKey.split("-")
        label.textContent = `${year}/${month}`
        fragment.appendChild(label)
        lastMonthKey = monthKey
      }

      const button = document.createElement("button")
      button.type = "button"
      button.className = "timeline-minimap__week"
      button.dataset.weekStart = week.start_date
      button.title = `${week.label} (${week.task_count}件)`
      button.textContent = week.label
      button.dataset.count = week.task_count
      button.style.setProperty("--task-count", week.task_count || 0)
      if (week.density) {
        button.dataset.density = week.density
        button.classList.add(`timeline-minimap__week--density-${week.density}`)
      }
      button.addEventListener("click", () => {
        if (this.state?.week?.start_date === week.start_date) return
        this.loadWeek(week.start_date)
      })

      if (this.state.week?.start_date === week.start_date) {
        button.classList.add("is-active")
      }

      fragment.appendChild(button)
    })

    this.minimapTarget.innerHTML = ""
    this.minimapTarget.appendChild(fragment)
  }

  renderUnscheduled(field) {
    const items = field.schedules?.unscheduled || []
    if (items.length === 0) return ""

    const listItems = items
      .map((item) => {
        const enriched = { ...item, field_cultivation_id: field.field_cultivation_id }
        const labelParts = [item.name]
        if (enriched.details?.stage?.name) labelParts.push(`(${enriched.details.stage.name})`)
        const detailPayload = this.encodeDetailPayload(enriched)
        const domId = this.taskDomId(enriched)
        const idAttr = domId ? ` id="${this.escapeHtml(domId)}"` : ""
        const dataDomAttr = domId ? ` data-dom-id="${this.escapeHtml(domId)}"` : ""

        return `
          <li class="timeline-unscheduled__item">
            <button type="button"
                    class="timeline-unscheduled__button"
                    data-undo-delete-record="true"${idAttr}${dataDomAttr}
                    data-detail="${detailPayload}"
                    data-field-id="${field.field_cultivation_id}"
                    data-item-id="${enriched.item_id}"
                    data-category="${enriched.category}"
                    data-action="task-schedule-timeline#showDetails">
              ${this.escapeHtml(labelParts.join(" "))}
            </button>
          </li>
        `
      })
      .join("")

    return `
      <div class="timeline-unscheduled">
        <div class="timeline-unscheduled__title">${this.escapeHtml(this.unscheduledTitle())}</div>
        <ul class="timeline-unscheduled__list">${listItems}</ul>
      </div>
    `
  }

  buildTasksByDate(field) {
    const map = new Map()
    const pushTask = (task) => {
      if (!task.scheduled_date) return
      const enriched = { ...task, field_cultivation_id: field.field_cultivation_id }
      if (!map.has(task.scheduled_date)) {
        map.set(task.scheduled_date, [])
      }
      map.get(task.scheduled_date).push(enriched)
    }

    ;(field.schedules?.general || []).forEach(pushTask)
    ;(field.schedules?.fertilizer || []).forEach(pushTask)
    return map
  }

  updateWeekLabel() {
    if (!this.hasWeekLabelTarget || !this.state?.week) return

    const start = new Date(this.state.week.start_date)
    const end = new Date(this.state.week.end_date)
    if (this.state.week.label) {
      this.weekLabelTarget.textContent = this.state.week.label
      return
    }

    const label = `${start.getFullYear()}/${start.getMonth() + 1}/${start.getDate()} 〜 ${end.getFullYear()}/${
      end.getMonth() + 1
    }/${end.getDate()}`
    this.weekLabelTarget.textContent = label
  }

  updateGeneratedAt() {
    if (!this.hasGeneratedAtTarget) return

    const plan = this.state?.plan || {}
    const display = plan.timeline_generated_at_display
    if (!display) {
      this.generatedAtTarget.textContent = this.unknownMessageValue || ""
      return
    }

    this.generatedAtTarget.textContent = `${this.generatedLabel()}: ${display}`
  }

  showDetails(event) {
    const encoded = event.currentTarget.getAttribute("data-detail")
    if (!encoded || !this.hasDetailPanelTarget) return

    let detail
    try {
      detail = JSON.parse(decodeURIComponent(encoded))
    } catch (e) {
      console.error("[TaskScheduleTimeline] failed to parse detail payload", e)
      return
    }

    const labels = this.detailLabels()
    const titleParts = [detail.name]
    if (this.hasDetailTitleTarget) {
      this.detailTitleTarget.textContent = titleParts.join(" ")
    }

    if (this.hasDetailListTarget) {
      const rows = []

      if (detail.scheduled_date) {
        rows.push(this.detailRow(labels.scheduled_date, this.formatDisplayDate(detail.scheduled_date)))
      }

      const stage = detail.details?.stage || {}
      if (stage.name) {
        const order = stage.order
        const hasOrder = order !== undefined && order !== null
        const stageValue = hasOrder ? `${stage.name} (#${order})` : stage.name
        rows.push(this.detailRow(labels.stage, stageValue))
      }

      if (detail.details?.time_per_sqm) {
        rows.push(this.detailRow(labels.time_per_sqm, detail.details.time_per_sqm))
      }

      if (detail.details?.amount) {
        const unit = detail.details.amount_unit || labels.amount_unit
        rows.push(this.detailRow(labels.amount, `${detail.details.amount} ${unit}`.trim()))
      }

      const master = detail.details?.master || {}
      if (master.name) {
        rows.push(this.detailRow(labels.master_name, master.name))
      }
      if (master.description) {
        rows.push(this.detailRow(labels.master_description, master.description))
      }
      if (master.required_tools && master.required_tools.length > 0) {
        rows.push(this.detailRow(labels.required_tools, master.required_tools.join(", ")))
      }
      if (rows.length === 0) {
        rows.push(this.detailRow(labels.not_applicable, labels.not_applicable))
      }

      this.detailListTarget.innerHTML = rows.join("")
    }

    if (this.hasDetailFormTarget) {
      this.detailFormTarget.innerHTML = ""
    }
    if (this.hasDetailActionsTarget) {
      this.renderDetailActions(detail)
    }
    this.currentDetail = detail
    this.currentCreateField = null

    this.openModal()
  }

  detailLabels() {
    const labels = this.state?.labels?.detail || {}
    const actionLabels = labels.actions || {}
    return {
      title: labels.title || "作業詳細",
      empty: labels.empty || "タスクを選択すると詳細を表示します",
      scheduled_date: labels.scheduled_date || "予定日",
      stage: labels.stage || "ステージ",
      time_per_sqm: labels.time_per_sqm || "作業時間 (h/㎡)",
      amount: labels.amount || "施肥量",
      amount_unit: labels.amount_unit || "単位",
      master_name: labels.master_name || "作業マスタ",
      master_description: labels.master_description || "作業説明",
      required_tools: labels.required_tools || "必要な工具",
      not_applicable: labels.not_applicable || "該当なし",
      statuses: labels.statuses || { completed: "完了", delayed: "遅延", adjusted: "調整済み" },
      actions: {
        reschedule: actionLabels.reschedule || "日付を変更",
        reschedule_label: actionLabels.reschedule_label || "新しい日付",
        updated: actionLabels.updated || "予定を更新しました",
        update_failed: actionLabels.update_failed || "更新に失敗しました",
        date_required: actionLabels.date_required || "日付を入力してください",
        submit: actionLabels.submit || "保存",
        cancel_form: actionLabels.cancel_form || "閉じる",
        complete: actionLabels.complete || "実績を登録",
        completed: actionLabels.completed || "実績を登録しました",
        complete_failed: actionLabels.complete_failed || "登録に失敗しました",
        actual_date: actionLabels.actual_date || "実施日",
        notes: actionLabels.notes || "メモ",
        notes_placeholder: actionLabels.notes_placeholder || "記録したい内容があれば入力してください",
        confirm_cancel: actionLabels.confirm_cancel || "この予定をキャンセルしますか？",
        cancel: actionLabels.cancel || "予定をキャンセル",
        cancel_failed: actionLabels.cancel_failed || "キャンセルに失敗しました",
        task_name: actionLabels.task_name || "作業名",
        task_name_placeholder: actionLabels.task_name_placeholder || "例: 温室換気",
        scheduled_date: actionLabels.scheduled_date || "予定日",
        name_required: actionLabels.name_required || "作業名を入力してください",
        created: actionLabels.created || "予定を追加しました",
        create_failed: actionLabels.create_failed || "追加に失敗しました"
      }
    }
  }

  detailRow(label, value) {
    return `<div class="detail-row">${this.escapeHtml(label)}: ${this.escapeHtml(value)}</div>`
  }

  renderDetailActions(detail) {
    if (!this.hasDetailActionsTarget) return
    const buttons = []

    if (detail.item_id) {
      buttons.push(
        `<button type="button" class="timeline-action-btn" data-action="task-schedule-timeline#openRescheduleForm">
          ${this.escapeHtml(this.detailLabels().actions?.reschedule || "日付を変更")}
        </button>`
      )
      buttons.push(
        `<button type="button" class="timeline-action-btn" data-action="task-schedule-timeline#openCompletionForm">
          ${this.escapeHtml(this.detailLabels().actions?.complete || "実績を登録")}
        </button>`
      )
      if ((detail.status || detail.badge?.status) !== "cancelled") {
        buttons.push(
          `<button type="button" class="timeline-action-btn timeline-action-btn--danger" data-action="task-schedule-timeline#cancelTask">
            ${this.escapeHtml(this.detailLabels().actions?.cancel || "予定をキャンセル")}
          </button>`
        )
      }
    }

    this.detailActionsTarget.innerHTML = buttons.join("")
  }

  openModal() {
    if (!this.hasModalTarget) return
    if (this.modalTarget.classList.contains("is-open")) return

    this.previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
    this.modalTarget.classList.add("is-open")
    this.modalTarget.removeAttribute("aria-hidden")
    document.body.classList.add("timeline-modal-open")

    if (this.hasModalDialogTarget) {
      this.modalDialogTarget.focus({ preventScroll: true })
    }
  }

  hideModal() {
    if (!this.hasModalTarget) return
    if (!this.modalTarget.classList.contains("is-open")) return

    this.modalTarget.classList.remove("is-open")
    this.modalTarget.setAttribute("aria-hidden", "true")
    document.body.classList.remove("timeline-modal-open")

    if (this.previousFocus && typeof this.previousFocus.focus === "function") {
      this.previousFocus.focus()
    }
    this.previousFocus = null
  }

  closeModal(event) {
    if (event) event.preventDefault()
    this.hideModal()
    this.resetDetailContent()
  }

  backdropClick(event) {
    if (!this.hasModalTarget) return
    if (event.target === this.modalTarget || event.target.classList.contains("timeline-modal__backdrop")) {
      this.closeModal(event)
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.isModalOpen()) {
      event.preventDefault()
      this.closeModal()
    }
  }

  isModalOpen() {
    return this.hasModalTarget && this.modalTarget.classList.contains("is-open")
  }

  encodeDetailPayload(task) {
    const payload = {
      item_id: task.item_id,
      field_cultivation_id: task.field_cultivation_id,
      dom_id: this.taskDomId(task),
      name: task.name,
      category: task.category,
      task_type: task.task_type,
      scheduled_date: task.scheduled_date,
      status: task.badge?.status,
      badge: task.badge || {},
      details: task.details || {}
    }
    return encodeURIComponent(JSON.stringify(payload))
  }

  encodeDataset(value) {
    try {
      return encodeURIComponent(JSON.stringify(value))
    } catch (error) {
      console.warn("[TaskScheduleTimeline] failed to encode dataset payload", error)
      return encodeURIComponent("[]")
    }
  }

  decodeDataset(value) {
    if (!value) return null
    try {
      return JSON.parse(decodeURIComponent(value))
    } catch (error) {
      console.warn("[TaskScheduleTimeline] failed to decode dataset payload", error)
      return null
    }
  }

  selectTaskChip(event) {
    event.preventDefault()
    const button = event.currentTarget
    const form = button.closest("form")
    if (!form) return

    const hiddenTaskId = form.querySelector('input[name="agricultural_task_id"]')
    const hiddenTemplateId = form.querySelector('input[name="crop_task_template_id"]')
    const nameInput = form.querySelector('input[name="name"]')
    if (!hiddenTaskId || !nameInput) return

    const taskId = button.dataset.taskId || ""
    const taskName = button.dataset.taskName || ""
    const templateId = button.dataset.templateId || ""

    hiddenTaskId.value = taskId
    if (hiddenTemplateId) hiddenTemplateId.value = templateId
    nameInput.value = taskName

    const descriptionInput = form.querySelector('textarea[name="description"]')
    if (descriptionInput && !descriptionInput.value.trim()) {
      descriptionInput.value = button.dataset.description || ""
    }

    form.querySelectorAll(".timeline-chip.is-active").forEach((chip) => chip.classList.remove("is-active"))
    button.classList.add("is-active")
  }

  handleNameInput(event) {
    const input = event.currentTarget
    const form = input.closest("form")
    if (!form) return

    const hiddenTaskId = form.querySelector('input[name="agricultural_task_id"]')
    const hiddenTemplateId = form.querySelector('input[name="crop_task_template_id"]')
    const activeChip = form.querySelector(".timeline-chip.is-active")
    if (!hiddenTaskId || !activeChip) return

    if (input.value !== activeChip.dataset.taskName) {
      activeChip.classList.remove("is-active")
      hiddenTaskId.value = ""
      if (hiddenTemplateId) hiddenTemplateId.value = ""
    }
  }

  changeScheduledDate(event) {
    event.preventDefault()
    const button = event.currentTarget
    const delta = Number(button.dataset.dateDelta || 0)
    if (!delta) return

    const form = button.closest("form")
    if (!form) return
    const input = form.querySelector('input[name="scheduled_date"]')
    if (!input || !input.value) return

    const date = new Date(input.value)
    if (Number.isNaN(date.getTime())) return

    date.setDate(date.getDate() + delta)
    input.value = this.formatDateISO(date)
  }

  openRescheduleForm(event) {
    event.preventDefault()
    if (!this.currentDetail?.item_id || !this.hasDetailFormTarget) return

    const defaultDate = this.currentDetail.scheduled_date || this.todayISO()
    this.detailFormTarget.innerHTML = `
      <form class="timeline-form" data-action="submit->task-schedule-timeline#submitReschedule">
        <label class="timeline-form__field">
          <span>${this.escapeHtml(this.detailLabels().actions?.reschedule_label || "新しい日付")}</span>
          <input type="date" name="scheduled_date" value="${defaultDate}">
        </label>
        <div class="timeline-form__actions">
          <button type="submit" class="btn btn-primary btn-sm">
            ${this.escapeHtml(this.detailLabels().actions?.submit || "保存")}
          </button>
          <button type="button" class="btn btn-secondary btn-sm" data-action="task-schedule-timeline#closeForm">
            ${this.escapeHtml(this.detailLabels().actions?.cancel_form || "閉じる")}
          </button>
        </div>
        <p class="timeline-form__message" data-timeline-form-message></p>
      </form>
    `
    this.clearFormMessage()
    this.openModal()
  }

  async submitReschedule(event) {
    event.preventDefault()
    if (!this.currentDetail?.item_id) return

    const form = event.target
    const formData = new FormData(form)
    const scheduledDate = formData.get("scheduled_date")

    if (!scheduledDate) {
      this.setFormMessage(this.detailLabels().actions?.date_required || "日付を入力してください")
      return
    }

    this.setFormPending(form, true)
    try {
      await this.patchItem(this.currentDetail.item_id, {
        task_schedule_item: { scheduled_date: scheduledDate }
      })
      this.setFormMessage(this.detailLabels().actions?.updated || "予定を更新しました", "success")
      await this.refreshCurrentWeek()
      this.closeForm()
    } catch (error) {
      this.setFormMessage(this.detailLabels().actions?.update_failed || "更新に失敗しました")
      console.error(error)
    } finally {
      this.setFormPending(form, false)
    }
  }

  openCompletionForm(event) {
    event.preventDefault()
    if (!this.currentDetail?.item_id || !this.hasDetailFormTarget) return

    const defaultDate = this.todayISO()
    this.detailFormTarget.innerHTML = `
      <form class="timeline-form" data-action="submit->task-schedule-timeline#submitCompletion">
        <label class="timeline-form__field">
          <span>${this.escapeHtml(this.detailLabels().actions?.actual_date || "実施日")}</span>
          <input type="date" name="actual_date" value="${defaultDate}">
        </label>
        <label class="timeline-form__field">
          <span>${this.escapeHtml(this.detailLabels().actions?.notes || "メモ")}</span>
          <textarea name="notes" rows="2" placeholder="${this.escapeHtml(
            this.detailLabels().actions?.notes_placeholder || "記録したい内容があれば入力してください"
          )}"></textarea>
        </label>
        <div class="timeline-form__actions">
          <button type="submit" class="btn btn-primary btn-sm">
            ${this.escapeHtml(this.detailLabels().actions?.submit || "保存")}
          </button>
          <button type="button" class="btn btn-secondary btn-sm" data-action="task-schedule-timeline#closeForm">
            ${this.escapeHtml(this.detailLabels().actions?.cancel_form || "閉じる")}
          </button>
        </div>
        <p class="timeline-form__message" data-timeline-form-message></p>
      </form>
    `
    this.clearFormMessage()
    this.openModal()
  }

  async submitCompletion(event) {
    event.preventDefault()
    if (!this.currentDetail?.item_id) return

    const form = event.target
    const formData = new FormData(form)
    const actualDate = formData.get("actual_date") || this.todayISO()
    const notes = formData.get("notes")

    this.setFormPending(form, true)
    try {
      await this.postCompletion(this.currentDetail.item_id, {
        completion: { actual_date: actualDate, notes }
      })
      this.setFormMessage(this.detailLabels().actions?.completed || "実績を登録しました", "success")
      await this.refreshCurrentWeek()
      this.closeForm()
    } catch (error) {
      this.setFormMessage(this.detailLabels().actions?.complete_failed || "登録に失敗しました")
      console.error(error)
    } finally {
      this.setFormPending(form, false)
    }
  }

  async cancelTask(event) {
    event.preventDefault()
    const detail = this.currentDetail
    if (!detail?.item_id) return

    const confirmed = window.confirm(this.detailLabels().actions?.confirm_cancel || "この予定をキャンセルしますか？")
    if (!confirmed) return

    try {
      const undoResponse = await this.deleteItem(detail.item_id)
      if (undoResponse && typeof undoResponse === "object") {
        const resourceDomId =
          undoResponse.resource_dom_id || detail.dom_id || this.taskDomId({ item_id: detail.item_id })
        this.hideTaskElement(resourceDomId, undoResponse.undo_token)
        window.dispatchEvent(new CustomEvent("undo:show", { detail: undoResponse }))
      }
      await this.refreshCurrentWeek()
      this.resetDetailPanel()
    } catch (error) {
      console.error(error)
      window.alert(this.detailLabels().actions?.cancel_failed || "キャンセルに失敗しました")
    }
  }

  openCreateForm(event) {
    event.preventDefault()
    const fieldId = Number(event.currentTarget.dataset.fieldId)
    if (!fieldId || !this.hasDetailFormTarget) return

    const fieldName = event.currentTarget.dataset.fieldName || ""
    const taskOptions = this.decodeDataset(event.currentTarget.dataset.taskOptions) || []
    const defaultCropId = event.currentTarget.dataset.cropId || (taskOptions[0]?.id != null ? String(taskOptions[0].id) : "")

    this.currentDetail = null
    this.currentCreateField = {
      id: fieldId,
      name: fieldName,
      cropName: event.currentTarget.dataset.cropName || "",
      taskOptions,
      defaultCropId,
      defaultScheduledDate: this.state?.week?.start_date || this.todayISO()
    }

    if (this.hasDetailTitleTarget) {
      this.detailTitleTarget.textContent = `${fieldName} - ${this.addTaskLabel()}`
    }
    if (this.hasDetailListTarget) {
      this.detailListTarget.innerHTML = ""
    }
    if (this.hasDetailActionsTarget) {
      this.detailActionsTarget.innerHTML = ""
    }

    this.renderCreateForm(fieldId, this.currentCreateField)
    this.openModal()
  }

  renderCreateForm(fieldId, context = {}) {
    const actions = this.detailLabels().actions || {}
    const taskOptions = (context.taskOptions || []).map((option) => {
      const templateId = option?.template_id ?? option?.templateId ?? null
      return {
        templateId: templateId != null ? String(templateId) : "",
        name: option?.name || "",
        taskType: option?.task_type || "field_work",
        agriculturalTaskId:
          option?.agricultural_task_id != null ? String(option.agricultural_task_id) : "",
        description: option?.description || "",
        weatherDependency: option?.weather_dependency || "",
        timePerSqm: option?.time_per_sqm || "",
        requiredTools: option?.required_tools || [],
        skillLevel: option?.skill_level || ""
      }
    })
    const defaultCropId = context.defaultCropId || ""
    const hasCropOptions = Boolean(defaultCropId)
    const cropLabel = context.cropName || ""
    const cropLabelText = cropLabel || actions.crop_required || "作物を選択してください"

    this.detailFormTarget.innerHTML = `
      <form class="timeline-form" data-action="submit->task-schedule-timeline#submitCreate">
        <input type="hidden" name="field_cultivation_id" value="${fieldId}">
        <input type="hidden" name="cultivation_plan_crop_id" value="${this.escapeHtml(defaultCropId)}">
        <input type="hidden" name="agricultural_task_id" value="">
        <input type="hidden" name="crop_task_template_id" value="">
        <div class="timeline-form__field">
          <span>${this.escapeHtml(actions.crop || "作物")}</span>
          <span class="timeline-form__static">${this.escapeHtml(cropLabelText)}</span>
        </div>
        ${
          taskOptions.length > 0
            ? `<div class="timeline-chip-list" data-task-chip-list>
                ${taskOptions
                  .map((option) => {
                    return `<button type="button"
                                    class="timeline-chip"
                                    data-action="task-schedule-timeline#selectTaskChip"
                                    data-template-id="${this.escapeHtml(option.templateId)}"
                                    data-task-id="${this.escapeHtml(option.agriculturalTaskId || "")}"
                                    data-task-name="${this.escapeHtml(option.name)}"
                                    data-description="${this.escapeHtml(option.description || "")}">
                              ${this.escapeHtml(option.name)}
                            </button>`
                  })
                  .join("")}
              </div>`
            : `<p class="timeline-form__hint">${this.escapeHtml(actions.name_required || "作業名を入力してください")}</p>`
        }
        <label class="timeline-form__field">
          <span>${this.escapeHtml(this.detailLabels().actions?.task_name || "作業名")}</span>
          <input type="text" name="name" required placeholder="${this.escapeHtml(
            this.detailLabels().actions?.task_name_placeholder || "例: 温室換気"
          )}" data-action="input->task-schedule-timeline#handleNameInput">
        </label>
        <label class="timeline-form__field">
          <span>${this.escapeHtml(this.detailLabels().actions?.scheduled_date || "予定日")}</span>
          <div class="timeline-date-input">
            <button type="button"
                    class="timeline-date-btn"
                    data-date-delta="-1"
                    data-action="task-schedule-timeline#changeScheduledDate">−</button>
            <input type="date" name="scheduled_date" value="${context.defaultScheduledDate}" required>
            <button type="button"
                    class="timeline-date-btn"
                    data-date-delta="1"
                    data-action="task-schedule-timeline#changeScheduledDate">＋</button>
          </div>
        </label>
        <label class="timeline-form__field">
          <span>${this.escapeHtml(this.detailLabels().actions?.notes || "メモ")}</span>
          <textarea name="description" rows="2" placeholder="${this.escapeHtml(
            this.detailLabels().actions?.notes_placeholder || "現場メモや準備物を入力できます"
          )}"></textarea>
        </label>
        <div class="timeline-form__actions">
          <button type="submit" class="btn btn-primary btn-sm"${hasCropOptions ? "" : " disabled"}>
            ${this.escapeHtml(this.detailLabels().actions?.submit || "保存")}
          </button>
          <button type="button" class="btn btn-secondary btn-sm" data-action="task-schedule-timeline#closeForm">
            ${this.escapeHtml(this.detailLabels().actions?.cancel_form || "閉じる")}
          </button>
        </div>
        <p class="timeline-form__message" data-timeline-form-message></p>
      </form>
    `
    this.clearFormMessage()
  }

  async submitCreate(event) {
    event.preventDefault()
    if (!this.currentCreateField) return

    const form = event.target
    const formData = new FormData(form)
    const name = formData.get("name")?.trim()
    const cropId = formData.get("cultivation_plan_crop_id")

    if (!name) {
      this.setFormMessage(this.detailLabels().actions?.name_required || "作業名を入力してください")
      return
    }
    if (!cropId) {
      this.setFormMessage(this.detailLabels().actions?.crop_required || "作物を選択してください")
      return
    }

    this.setFormPending(form, true)
    try {
      const payload = {
        task_schedule_item: {
          field_cultivation_id: this.currentCreateField.id,
          name,
          task_type: "field_work",
          scheduled_date: formData.get("scheduled_date"),
          agricultural_task_id: formData.get("agricultural_task_id") || null,
          cultivation_plan_crop_id: cropId,
          description: formData.get("description")
        }
      }
      const templateId = formData.get("crop_task_template_id")
      if (templateId) {
        payload.task_schedule_item.crop_task_template_id = templateId
      }
      await this.postItem(payload)
      this.setFormMessage(this.detailLabels().actions?.created || "予定を追加しました", "success")
      await this.refreshCurrentWeek()
      this.resetDetailPanel()
    } catch (error) {
      this.setFormMessage(this.detailLabels().actions?.create_failed || "追加に失敗しました")
      console.error(error)
    } finally {
      this.setFormPending(form, false)
    }
  }

  closeForm(event) {
    if (event) {
      event.preventDefault()
    }
    if (this.hasDetailFormTarget) {
      this.detailFormTarget.innerHTML = ""
    }
    this.clearFormMessage()
    if (!this.currentDetail) {
      this.hideModal()
      this.resetDetailContent()
    }
  }

  async postItem(payload) {
    const response = await fetch(this.itemsEndpointValue, {
      method: "POST",
      headers: this.requestHeaders(),
      body: JSON.stringify(payload)
    })
    if (!response.ok) {
      const data = await response.json().catch(() => ({}))
      throw new Error(data.error || "Failed to create task")
    }
    return response.json()
  }

  async patchItem(itemId, payload) {
    const response = await fetch(this.itemUrl(itemId), {
      method: "PATCH",
      headers: this.requestHeaders(),
      body: JSON.stringify(payload)
    })
    if (!response.ok) {
      const data = await response.json().catch(() => ({}))
      throw new Error(data.error || "Failed to update task")
    }
    return response.json()
  }

  async deleteItem(itemId) {
    const response = await fetch(this.itemUrl(itemId), {
      method: "DELETE",
      headers: this.requestHeaders()
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(data.error || "Failed to cancel task")
    }
    return data
  }

  async postCompletion(itemId, payload) {
    const response = await fetch(`${this.itemUrl(itemId)}/complete`, {
      method: "POST",
      headers: this.requestHeaders(),
      body: JSON.stringify(payload)
    })
    if (!response.ok) {
      const data = await response.json().catch(() => ({}))
      throw new Error(data.error || "Failed to register completion")
    }
    return response.json()
  }

  hideTaskElement(domId, undoToken) {
    const element = this.findRecordElementByDomId(domId)
    if (!element) return

    element.classList.add("undo-delete--hidden")
    if (undoToken) {
      element.dataset.undoDeleteToken = undoToken
    }
  }

  findRecordElementByDomId(domId) {
    if (!domId) return null
    const selector = `#${this.escapeSelector(domId)}`
    if (this.element) {
      const within = this.element.querySelector(selector)
      if (within) return within
    }
    return document.querySelector(selector)
  }

  handleUndoRestored(event) {
    const token = event?.detail?.undo_token
    if (!token) return

    const selector = `[data-undo-delete-token="${this.escapeSelector(token)}"]`
    const element = document.querySelector(selector)
    if (element) {
      element.classList.remove("undo-delete--hidden")
      delete element.dataset.undoDeleteToken
    }

    this.refreshCurrentWeek({ showLoading: false })
  }

  taskDomId(task) {
    if (!task) return null
    if (task.dom_id) return task.dom_id
    if (task.resource_dom_id) return task.resource_dom_id

    const rawId = task.item_id ?? task.id
    if (rawId == null) return null

    const stringId = String(rawId)
    if (stringId.startsWith("task_schedule_item_")) {
      return stringId
    }
    return `task_schedule_item_${stringId}`
  }

  setFormPending(form, pending) {
    Array.from(form.elements).forEach((el) => {
      el.disabled = pending && el.type !== "hidden"
    })
  }

  setFormMessage(message, type = "error") {
    const el = this.formMessageElement()
    if (!el) return
    if (this.formMessageTimer) {
      clearTimeout(this.formMessageTimer)
    }
    el.textContent = message
    el.classList.remove("timeline-form__message--error", "timeline-form__message--success")
    el.classList.add(type === "success" ? "timeline-form__message--success" : "timeline-form__message--error")
    this.formMessageTimer = setTimeout(() => {
      this.clearFormMessage()
    }, 4000)
  }

  clearFormMessage() {
    const el = this.formMessageElement()
    if (!el) return
    el.textContent = ""
    el.classList.remove("timeline-form__message--error", "timeline-form__message--success")
    if (this.formMessageTimer) {
      clearTimeout(this.formMessageTimer)
      this.formMessageTimer = null
    }
  }

  formMessageElement() {
    if (!this.hasDetailFormTarget) return null
    return this.detailFormTarget.querySelector("[data-timeline-form-message]")
  }

  requestHeaders() {
    return {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": this.csrfToken()
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }

  itemUrl(itemId) {
    const base = this.itemsEndpointValue || ""
    return `${base}/${itemId}`
  }

  refreshCurrentWeek(options = {}) {
    if (this.state?.week?.start_date) {
      return this.loadWeek(this.state.week.start_date, options)
    }
    const monday = this.beginningOfWeek(new Date())
    return this.loadWeek(this.formatDateISO(monday), options)
  }

  todayISO() {
    return this.formatDateISO(new Date())
  }

  formatDisplayDate(value) {
    if (!value) return this.detailLabels().not_applicable
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return value
    return `${date.getFullYear()}/${this.pad(date.getMonth() + 1)}/${this.pad(date.getDate())} (${this.weekdayLabel(
      date
    )})`
  }

  showLoading() {
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = `<div class="task-schedule-loading">${this.escapeHtml(
        this.loadingMessageValue || "Loading..."
      )}</div>`
    }
  }

  showError() {
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = `<div class="task-schedule-error">${this.escapeHtml(
        this.errorMessageValue || "Failed to load"
      )}</div>`
    }
  }

  beginningOfWeek(date) {
    const d = new Date(date)
    const day = d.getDay()
    const diff = d.getDate() - day + (day === 0 ? -6 : 1) // adjust for Monday start
    d.setDate(diff)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate())
  }

  formatDateISO(date) {
    return `${date.getFullYear()}-${this.pad(date.getMonth() + 1)}-${this.pad(date.getDate())}`
  }

  pad(value) {
    return value.toString().padStart(2, "0")
  }

  weekdayLabel(date) {
    const weekdays = ["日", "月", "火", "水", "木", "金", "土"]
    return weekdays[date.getDay()]
  }

  emptyCellLabel() {
    return this.state?.labels?.empty_cell || "予定なし"
  }

  unscheduledTitle() {
    return this.state?.labels?.unscheduled_title || "未確定の作業"
  }

  addTaskLabel() {
    return this.state?.labels?.add_task || "予定追加"
  }

  generatedLabel() {
    return this.state?.labels?.generated_label || "生成日時"
  }

  formatNumber(value) {
    if (value == null) return ""
    return Number(value).toLocaleString()
  }

  escapeHtml(string) {
    return (string || "")
      .toString()
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  escapeSelector(value) {
    if (typeof window !== "undefined" && window.CSS && typeof window.CSS.escape === "function") {
      return window.CSS.escape(String(value))
    }
    return String(value).replace(/([ !"#$%&'()*+,./:;<=>?@[\\\]^`{|}~])/g, "\\$1")
  }
}

