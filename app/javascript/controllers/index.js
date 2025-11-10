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
import UndoToastController from "./undo_toast_controller"

console.log('[Controllers] Registering controllers...')
console.log('[Controllers] CropAiController:', CropAiController)
console.log('[Controllers] FertilizeAiController:', FertilizeAiController)
console.log('[Controllers] PestAiController:', PestAiController)

application.register("crop-ai", CropAiController)
application.register("fertilize-ai", FertilizeAiController)
application.register("pest-ai", PestAiController)
application.register("task-schedule-timeline", TaskScheduleTimelineController)
application.register("undo-delete", UndoDeleteController)
application.register("undo-toast", UndoToastController)

console.log('[Controllers] Registered controllers:', Object.keys(application.controllers))
console.log('[Controllers] Check fertilize-ai:', application.getControllerForElementAndIdentifier)

export { application }
