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
import CropFertilizeProfileAiController from "./crop_fertilize_profile_ai_controller"

console.log('[Controllers] Registering controllers...')
console.log('[Controllers] CropAiController:', CropAiController)
console.log('[Controllers] FertilizeAiController:', FertilizeAiController)
console.log('[Controllers] CropFertilizeProfileAiController:', CropFertilizeProfileAiController)

application.register("crop-ai", CropAiController)
application.register("fertilize-ai", FertilizeAiController)
application.register("crop-fertilize-profile-ai", CropFertilizeProfileAiController)

console.log('[Controllers] Registered controllers:', Object.keys(application.controllers))
console.log('[Controllers] Check fertilize-ai:', application.getControllerForElementAndIdentifier)

export { application }
