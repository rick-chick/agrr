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
    "minimap"
  ]

  static values = {
    endpoint: String,
    initialState: Object,
    loadingMessage: String,
    errorMessage: String,
    emptyMessage: String,
    unknownMessage: String
  }

  connect() {
    this.state = this.initialStateValue || null
    this.render()
  }

  disconnect() {
    if (this._abortController) {
      this._abortController.abort()
    }
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

  loadWeek(weekStartIso) {
    const url = new URL(this.endpointValue, window.location.origin)
    url.searchParams.set("week_start", weekStartIso)

    this.showLoading()

    if (this._abortController) {
      this._abortController.abort()
    }
    this._abortController = new AbortController()

    fetch(url.toString(), {
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
    if (!this.hasDetailPanelTarget) return

    this.detailPanelTarget.classList.add("hidden")
    if (this.hasDetailTitleTarget) this.detailTitleTarget.textContent = this.detailLabels().title || ""
    if (this.hasDetailListTarget) {
      this.detailListTarget.innerHTML = `<div class="detail-row detail-row--empty">${this.escapeHtml(
        this.detailLabels().empty
      )}</div>`
    }
  }

  renderFieldBlock(field, weekDays) {
    const fieldHeader = `
      <header class="task-schedule-field__header">
        <div class="task-schedule-field__name">${this.escapeHtml(field.name || "")}</div>
        <div class="task-schedule-field__subtitle">
          ${this.renderFieldSubtitle(field)}
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

    const taskRows = weekDays.map((day) => this.renderDayCell(day, tasksByDate.get(day.date) || [])).join("")

    return `
      <div class="timeline-grid">
        <div class="timeline-day-header-row">${headerRow}</div>
        <div class="timeline-day-cells">${taskRows}</div>
      </div>
    `
  }

  renderDayCell(day, tasks) {
    if (!tasks.length) {
      return `<div class="timeline-day-cell timeline-day-cell--empty">${this.escapeHtml(
        this.emptyCellLabel()
      )}</div>`
    }

    const taskHtml = tasks.map((task) => this.renderTask(task)).join("")

    return `<div class="timeline-day-cell">${taskHtml}</div>`
  }

  renderTask(task) {
    const classes = ["timeline-task"]
    classes.push(task.category === "fertilizer" ? "timeline-task--fertilizer" : "timeline-task--general")

    if (task.badge?.priority_level) classes.push(`timeline-task--${task.badge.priority_level}`)
    if (task.badge?.status) classes.push(`timeline-task--status-${task.badge.status}`)

    const stageLabel =
      task.details?.stage?.name && task.details.stage.name.length > 0
        ? `<span class="timeline-task__stage">${this.escapeHtml(task.details.stage.name)}</span>`
        : ""

    const badge = this.renderTaskBadge(task)

    const detailPayload = this.encodeDetailPayload(task)

    return `
      <button type="button"
              class="${classes.join(" ")}"
              data-detail="${detailPayload}"
              data-action="task-schedule-timeline#showDetails">
        <span class="timeline-task__name">${this.escapeHtml(task.name)}</span>
        ${stageLabel}
        ${badge}
      </button>
    `
  }

  renderTaskBadge(task) {
    const parts = []
    if (task.details?.priority != null) {
      const priorityText = this.priorityLabel(task.details.priority)
      if (priorityText) parts.push(priorityText)
    }

    const statusText = this.statusLabel(task.badge?.status)
    if (statusText) parts.push(statusText)

    if (parts.length === 0) return ""

    return `<span class="timeline-task__badge">${this.escapeHtml(parts.join(" / "))}</span>`
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
        const labelParts = [item.name]
        if (item.details?.stage?.name) labelParts.push(`(${item.details.stage.name})`)
        const detailPayload = this.encodeDetailPayload(item)
        return `
          <li class="timeline-unscheduled__item">
            <button type="button"
                    class="timeline-unscheduled__button"
                    data-detail="${detailPayload}"
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
      if (!map.has(task.scheduled_date)) {
        map.set(task.scheduled_date, [])
      }
      map.get(task.scheduled_date).push(task)
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
    const categoryLabel = this.categoryLabel(detail.category)
    if (categoryLabel) titleParts.push(`(${categoryLabel})`)

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

      const priorityValue = this.priorityLabel(detail.details?.priority)
      if (priorityValue) {
        rows.push(this.detailRow(labels.priority, priorityValue))
      }

      if (detail.details?.weather_dependency) {
        rows.push(this.detailRow(labels.weather_dependency, detail.details.weather_dependency))
      }

      if (detail.details?.gdd?.trigger) {
        rows.push(this.detailRow(labels.gdd_trigger, detail.details.gdd.trigger))
      }

      if (detail.details?.gdd?.tolerance) {
        rows.push(this.detailRow(labels.gdd_tolerance, detail.details.gdd.tolerance))
      }

      if (detail.details?.time_per_sqm) {
        rows.push(this.detailRow(labels.time_per_sqm, detail.details.time_per_sqm))
      }

      if (detail.details?.amount) {
        const unit = detail.details.amount_unit || labels.amount_unit
        rows.push(this.detailRow(labels.amount, `${detail.details.amount} ${unit}`.trim()))
      }

      if (detail.details?.source) {
        rows.push(this.detailRow(labels.source, detail.details.source))
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
      if (master.skill_level) {
        rows.push(this.detailRow(labels.skill_level, this.skillLevelLabel(master.skill_level)))
      }
      if (master.weather_dependency && !detail.details?.weather_dependency) {
        rows.push(this.detailRow(labels.weather_dependency, master.weather_dependency))
      }
      if (master.time_per_sqm && !detail.details?.time_per_sqm) {
        rows.push(this.detailRow(labels.time_per_sqm, master.time_per_sqm))
      }

      if (rows.length === 0) {
        rows.push(this.detailRow(labels.not_applicable, labels.not_applicable))
      }

      this.detailListTarget.innerHTML = rows.join("")
    }

    this.detailPanelTarget.classList.remove("hidden")
  }

  detailLabels() {
    const labels = this.state?.labels?.detail || {}
    const skillLevelLabels = labels.skill_level_labels || {}
    return {
      title: labels.title || "作業詳細",
      empty: labels.empty || "タスクを選択すると詳細を表示します",
      scheduled_date: labels.scheduled_date || "予定日",
      stage: labels.stage || "ステージ",
      priority: labels.priority || "優先度",
      priority_levels: labels.priority_levels || {
        high: "高",
        medium: "中",
        low: "低",
        unknown: "未設定"
      },
      weather_dependency: labels.weather_dependency || "天候条件",
      gdd_trigger: labels.gdd_trigger || "GDD トリガー",
      gdd_tolerance: labels.gdd_tolerance || "GDD 許容",
      time_per_sqm: labels.time_per_sqm || "作業時間 (h/㎡)",
      amount: labels.amount || "施肥量",
      amount_unit: labels.amount_unit || "単位",
      source: labels.source || "出典",
      master_name: labels.master_name || "作業マスタ",
      master_description: labels.master_description || "作業説明",
      required_tools: labels.required_tools || "必要な工具",
      skill_level: labels.skill_level || "推奨スキル",
      skill_level_beginner: skillLevelLabels.beginner || "初級",
      skill_level_intermediate: skillLevelLabels.intermediate || "中級",
      skill_level_advanced: skillLevelLabels.advanced || "上級",
      not_applicable: labels.not_applicable || "該当なし",
      statuses: labels.statuses || { completed: "完了", delayed: "遅延", adjusted: "調整済み" }
    }
  }

  detailRow(label, value) {
    return `<div class="detail-row">${this.escapeHtml(label)}: ${this.escapeHtml(value)}</div>`
  }

  priorityLabel(priority) {
    const levels = this.detailLabels().priority_levels

    if (priority == null) return levels.unknown
    if (priority <= 1) return levels.high
    if (priority === 2) return levels.medium
    return levels.low
  }

  skillLevelLabel(level) {
    const mapping = {
      beginner: this.detailLabels().skill_level_beginner || "初級",
      intermediate: this.detailLabels().skill_level_intermediate || "中級",
      advanced: this.detailLabels().skill_level_advanced || "上級"
    }
    return mapping[level] || level
  }

  statusLabel(status) {
    if (!status || status === "planned") return ""
    const labels = this.detailLabels().statuses || {}
    return labels[status] || status
  }

  categoryLabel(category) {
    if (!this.state?.labels) return category
    if (category === "general") return this.state.labels.general_label || category
    if (category === "fertilizer") return this.state.labels.fertilizer_label || category
    return category
  }

  encodeDetailPayload(task) {
    const payload = {
      name: task.name,
      category: task.category,
      task_type: task.task_type,
      scheduled_date: task.scheduled_date,
      badge: task.badge || {},
      details: task.details || {}
    }
    return encodeURIComponent(JSON.stringify(payload))
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
}

