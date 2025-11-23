// Load all the controllers within this directory and all subdirectories. 
// Controller files must be named *_controller.js.

import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = true  // デバッグモードを有効化
window.Stimulus = application

// Register controllers manually
import CropAiController from "./crop_ai_controller"
import FertilizeAiController from "./fertilize_ai_controller"
import PestAiController from "./pest_ai_controller"
import TaskScheduleTimelineController from "./task_schedule_timeline_controller"
import UndoDeleteController from "./undo_delete_controller"
import PlansShowController from "./plans_show_controller"
import OptimizingController from "./optimizing_controller"
import UndoToastController from "./undo_toast_controller"
import CropSelectorController from "./crop_selector_controller"
import CropSelectController from "./crop_select_controller"
import AgriculturalTaskFormController from "./agricultural_task_form_controller"
import TaskBlueprintCardDragController from "./task_blueprint_card_drag_controller"
import PestFormController from "./pest_form_controller"
import PlanningSchedulesFieldsSelectionController from "./planning_schedules_fields_selection_controller"
import NavbarController from "./navbar_controller"
import DropdownController from "./dropdown_controller"
import StopPropagationController from "./stop_propagation_controller"
import ToastNotificationController from "./toast_notification_controller"

console.log('[Controllers] Registering controllers...')
console.log('[Controllers] CropAiController:', CropAiController)

application.register("plans-show", PlansShowController)
console.log('[Controllers] FertilizeAiController:', FertilizeAiController)
console.log('[Controllers] PestAiController:', PestAiController)

application.register("crop-ai", CropAiController)
application.register("fertilize-ai", FertilizeAiController)
application.register("pest-ai", PestAiController)
application.register("task-schedule-timeline", TaskScheduleTimelineController)
application.register("undo-delete", UndoDeleteController)
application.register("optimizing", OptimizingController)
application.register("undo-toast", UndoToastController)
application.register("crop-selector", CropSelectorController)
application.register("crop-select", CropSelectController)
application.register("agricultural-task-form", AgriculturalTaskFormController)
application.register("task-blueprint-card-drag", TaskBlueprintCardDragController)
application.register("pest-form", PestFormController)
application.register("planning-schedules-fields-selection", PlanningSchedulesFieldsSelectionController)
application.register("navbar", NavbarController)
application.register("dropdown", DropdownController)
application.register("stop-propagation", StopPropagationController)
application.register("toast-notification", ToastNotificationController)

console.log('[Controllers] Registered controllers:', Object.keys(application.controllers))
console.log('[Controllers] Check fertilize-ai:', application.getControllerForElementAndIdentifier)

export { application }
