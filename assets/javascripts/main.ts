import Turbolinks from 'turbolinks'
import './turbolinks-prefetch'

import 'main.css'

import { render, cancel } from 'timeago.js'

document.addEventListener("turbolinks:load", function () {
  const nodes = document.querySelectorAll('.timeago')
  if (nodes.length > 0) {
    render(nodes, 'en_US')
    cancel()
  }
})

Turbolinks.start()