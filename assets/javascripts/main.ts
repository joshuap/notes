import 'main.css'

import { render, cancel } from 'timeago.js'

(function () {
  const nodes = document.querySelectorAll('.timeago')
  console.log(nodes)
  render(nodes, 'en_US')
  cancel();
})()