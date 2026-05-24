// Load all the controllers within this directory and all subdirectories.
// Controller files must be named *_controller.js.

import { Application } from "@hotwired/stimulus"

const application = Application.start()

application.debug = true
window.Stimulus = application

import NavbarController from "./navbar_controller"
import DropdownController from "./dropdown_controller"
import UndoToastController from "./undo_toast_controller"
import CookieConsentController from "./cookie_consent_controller"

application.register("navbar", NavbarController)
application.register("dropdown", DropdownController)
application.register("undo-toast", UndoToastController)
application.register("cookie-consent", CookieConsentController)

export { application }
