import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    try {
      this.subscription = null;
      this.elapsedTimer = null;
      this.startTime = null;
      this.currentPlanId = null;
      this.cableManagerWaitCount = 0;
      this.reconnectAttempts = 0;
      this.MAX_RECONNECT_ATTEMPTS = 1;

      this.init();
    } catch (e) {
      console.error("[optimizing] connect error", e);
    }
  }

  disconnect() {
    try {
      this.cleanup();
    } catch (e) {
      console.error("[optimizing] disconnect error", e);
    }
  }

  init = () => {
    const container = this.element;
    if (!container || !container.hasAttribute("data-optimizing-container")) {
      this.cleanup();
      return;
    }

    this.connectionErrorMessage =
      container.dataset.connectionErrorMessage ||
      "Connection lost. Please try again.";
    this.unknownErrorMessage =
      container.dataset.unknownErrorMessage ||
      "An unknown error occurred.";
    this.failedTitle =
      container.dataset.failedTitle || "Optimization failed";

    if (typeof window.CableSubscriptionManager === "undefined") {
      this.cableManagerWaitCount += 1;
      if (this.cableManagerWaitCount > 50) {
        this.showConnectionError("❌ CableSubscriptionManager failed to load after 5 seconds");
        return;
      }
      setTimeout(this.init, 100);
      return;
    }

    const isResultsPage = window.location.pathname.includes("/results") ||
                          document.querySelector(".gantt-chart-container");
    if (isResultsPage) {
      this.cleanup();
      return;
    }

    const cultivationPlanId = container.dataset.cultivationPlanId;
    const channelName = container.dataset.channelName;
    const redirectUrl = container.dataset.redirectUrl;

    if (!cultivationPlanId) {
      console.error("❌ [Optimizing] cultivation_plan_id not found");
      return;
    }
    if (!redirectUrl) {
      console.error("❌ [Optimizing] redirect_url not found");
      return;
    }
    if (!channelName) {
      console.error("❌ [Optimizing] data-channel-name not found on optimizing container");
      return;
    }

    if (this.currentPlanId === cultivationPlanId && this.subscription) {
      return;
    }
    this.currentPlanId = cultivationPlanId;

    if (this.subscription && window.CableSubscriptionManager) {
      window.CableSubscriptionManager.unsubscribe(cultivationPlanId, { channelName });
      this.subscription = null;
    }

    this.startElapsedTimer();

    if (typeof window.CableSubscriptionManager === "undefined") {
      console.error("❌ [Optimizing] CableSubscriptionManager is not loaded");
      return;
    }

    this.subscription = window.CableSubscriptionManager.subscribeToOptimization(
      cultivationPlanId,
      {
        onConnected: () => {},
        onDisconnected: () => {
          if (this.reconnectAttempts < this.MAX_RECONNECT_ATTEMPTS) {
            this.reconnectAttempts += 1;
            setTimeout(this.init, 200);
          } else {
            this.showConnectionError(this.connectionErrorMessage);
          }
        },
        onReceived: (data) => {
          if (data.type === "redirect") {
            this.handleCompleted(data.redirect_path);
            return;
          }
          if (data.phase_message) {
            this.updatePhaseMessage(data.phase_message, data.status === "failed");
          }
          if (data.progress !== undefined) {
            this.updateProgressBar(data.progress);
          }
          if (data.status === "completed") {
            this.handleCompleted(redirectUrl);
          } else if (data.status === "failed") {
            this.handleFailed(data);
          }
        }
      },
      { channelName }
    );
  }

  updatePhaseMessage = (message, isError = false) => {
    const phaseMessageElement = document.getElementById("phase-message");
    if (phaseMessageElement) {
      phaseMessageElement.textContent = message;
      if (isError) {
        phaseMessageElement.classList.add("error");
      } else {
        phaseMessageElement.classList.remove("error");
      }
    }

    const progressMessageElement = document.getElementById("progressMessage");
    if (progressMessageElement) {
      progressMessageElement.textContent = message;
      if (isError) {
        progressMessageElement.style.color = "var(--color-danger)";
      } else {
        progressMessageElement.style.color = "";
      }
    }
  }

  updateProgressBar = (progress) => {
    const progressBar = document.getElementById("progressBar");
    const progressPercentage = document.getElementById("progressPercentage");
    if (progressBar) progressBar.style.width = progress + "%";
    if (progressPercentage) progressPercentage.textContent = progress + "%";
  }

  handleCompleted = (redirectUrl) => {
    const spinner = document.getElementById("loading-spinner");
    if (spinner) spinner.classList.add("hidden");
    if (this.elapsedTimer) {
      clearInterval(this.elapsedTimer);
      this.elapsedTimer = null;
    }
    setTimeout(() => {
      window.location.href = redirectUrl;
    }, 500);
  }

  handleFailed = (data) => {
    if (this.elapsedTimer) {
      clearInterval(this.elapsedTimer);
      this.elapsedTimer = null;
    }
    const spinner = document.getElementById("loading-spinner");
    if (spinner) spinner.classList.add("hidden");
    const durationHint = document.getElementById("progress-duration-hint");
    if (durationHint) durationHint.style.display = "none";
    const elapsedTime = document.getElementById("elapsed-time");
    if (elapsedTime) elapsedTime.style.display = "none";

    const errorContainer = document.getElementById("error-message-container");
    const errorDetail = document.getElementById("error-detail");
    if (errorContainer && errorDetail) {
      errorDetail.textContent =
        data.phase_message || data.message || this.unknownErrorMessage;
      errorContainer.style.display = "flex";
    }

    const progressMessageElement = document.getElementById("progressMessage");
    if (progressMessageElement) {
      const errorTitle =
        progressMessageElement.dataset.errorTitle ||
        this.failedTitle;
      progressMessageElement.textContent = errorTitle;
      progressMessageElement.style.color = "var(--color-danger)";
    }
  }

  showConnectionError = (message) => {
    const errorContainer = document.getElementById("error-message-container");
    const errorDetail = document.getElementById("error-detail");
    if (errorContainer && errorDetail) {
      errorDetail.textContent = message;
      errorContainer.style.display = "flex";
    }
    const spinner = document.getElementById("loading-spinner");
    if (spinner) spinner.classList.add("hidden");
    const durationHint = document.getElementById("progress-duration-hint");
    if (durationHint) durationHint.style.display = "none";
    const elapsedTime = document.getElementById("elapsed-time");
    if (elapsedTime) elapsedTime.style.display = "none";
  }

  startElapsedTimer = () => {
    const elapsedTimeElementPublic = document.getElementById("elapsed-time");
    const elapsedTimeElementPlans = document.getElementById("elapsedTime");
    if (!elapsedTimeElementPublic && !elapsedTimeElementPlans) return;
    if (!this.startTime) this.startTime = Date.now();
    if (this.elapsedTimer) clearInterval(this.elapsedTimer);

    this.elapsedTimer = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.startTime) / 1000);
      const minutes = Math.floor(elapsed / 60);
      const seconds = elapsed % 60;

      if (elapsedTimeElementPublic) {
        const template = elapsedTimeElementPublic.dataset.elapsedTimeTemplate || "⏳ %{time}";
        if (minutes > 0) {
          const minuteTemplate = elapsedTimeElementPublic.dataset.elapsedTimeMinuteTemplate;
          if (minuteTemplate) {
            elapsedTimeElementPublic.textContent = minuteTemplate
              .replace("%{minutes}", minutes)
              .replace("%{seconds}", seconds);
          } else {
            elapsedTimeElementPublic.textContent = `${minutes}:${String(seconds).padStart(2, "0")}`;
          }
        } else {
          elapsedTimeElementPublic.textContent = template.replace("%{time}", seconds.toString());
        }
      }

      if (elapsedTimeElementPlans) {
        if (minutes > 0) {
          const template = elapsedTimeElementPlans.dataset.templateMinute || "%{minutes}分%{seconds}秒";
          elapsedTimeElementPlans.textContent = template
            .replace("%{minutes}", minutes)
            .replace("%{seconds}", seconds.toString().padStart(2, "0"));
        } else {
          const template = elapsedTimeElementPlans.dataset.templateSecond || "⏳ %{time}秒";
          elapsedTimeElementPlans.textContent = template.replace("%{time}", elapsed);
        }
      }
    }, 1000);
  }

  cleanup = () => {
    if (this.elapsedTimer) {
      clearInterval(this.elapsedTimer);
      this.elapsedTimer = null;
    }
    if (this.subscription && window.CableSubscriptionManager) {
      const cultivationPlanId = this.element?.dataset?.cultivationPlanId;
      const channelName = this.element?.dataset?.channelName;
      if (cultivationPlanId && channelName) {
        window.CableSubscriptionManager.unsubscribe(cultivationPlanId, { channelName });
      }
      this.subscription = null;
    }
    this.startTime = null;
    this.currentPlanId = null;
    this.cableManagerWaitCount = 0;
    this.reconnectAttempts = 0;
  }
}


