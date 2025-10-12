// Load all the controllers within this directory and all subdirectories. 
// Controller files must be named *_controller.js.

import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Register controllers manually
import CropAiController from "./crop_ai_controller"
application.register("crop-ai", CropAiController)

export { application }
