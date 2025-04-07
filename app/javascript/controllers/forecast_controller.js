import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "results"]

  connect() {
    console.log("Forecast controller connected")
  }

  submit(event) {
    event.preventDefault()
    
    const form = this.formTarget
    const formData = new FormData(form)
    const url = form.action + "?" + new URLSearchParams(formData).toString()
    
    fetch(url, {
      headers: {
        "Accept": "text/javascript"
      }
    })
    .then(response => response.text())
    .then(script => {
      eval(script)
    })
    .catch(error => {
      console.error("Error fetching forecast:", error)
    })
  }
} 