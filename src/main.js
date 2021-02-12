import { Elm } from './Main.elm'

const loader = document.getElementById('loader')
document.body.removeChild(loader)

const node = document.createElement('div')

document.body.appendChild(node)

const seed = crypto.getRandomValues(new Uint16Array(1))[0]

const seeds = crypto.getRandomValues(new Uint16Array(1000))

Elm.Main.init({
  node,
  flags: {
    seed,
    seeds: [...seeds]
  }
})
