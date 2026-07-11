import { basename } from "node:path"
import { readFileSync } from "node:fs"
import { StyledText, TextRenderable, bg, bold, fg } from "@opentui/core"

const BLUE = "#7aa2f7"
const CYAN = "#7dcfff"
const GREEN = "#9ece6a"
const PURPLE = "#bb9af7"
const DARK = "#1a1b26"
const MUTED = "#565f89"

function clean(value, fallback = "-") {
  const text = String(value ?? "").replace(/[\x00-\x1f\x7f]/g, "").trim()
  return text || fallback
}

function modes() {
  try {
    const text = readFileSync(`${process.env.XDG_CONFIG_HOME || `${process.env.HOME}/.config`}/aicli-ultimate/modes`, "utf8")
    const active = []
    if (/^caveman=(?!off)/m.test(text)) active.push("caveman")
    if (/^ponytail=(?!off)/m.test(text)) active.push("ponytail")
    return active.join("+") || "standard"
  } catch {
    return "standard"
  }
}

function content(api) {
  const branch = clean(api.state.vcs?.branch, "no-git")
  const directory = basename(clean(api.state.path.directory, "~")) || "~"
  const clock = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  const plain = ` OpenCode · ${directory} ·  ${branch} · ${modes()} · ${clock} `
  if (process.env.NO_COLOR) return plain
  return new StyledText([
    bg(BLUE)(fg(DARK)(bold(" OpenCode "))),
    fg(BLUE)(""),
    fg(CYAN)(` ${directory} `),
    fg(MUTED)(""),
    fg(GREEN)(`  ${branch} `),
    fg(MUTED)(""),
    fg(PURPLE)(` ${modes()} `),
    fg(MUTED)(`  ${clock} `),
  ])
}

export default {
  id: "aicli-ultimate-statusline",
  async tui(api) {
    const nodes = new Set()
    const make = (id) => {
      const node = new TextRenderable(api.renderer, {
        id: `aicli-ultimate-${id}`,
        content: content(api),
        height: 1,
      })
      nodes.add(node)
      return node
    }
    const timer = setInterval(() => {
      for (const node of nodes) node.content = content(api)
      api.renderer.requestRender?.()
    }, 10_000)
    api.lifecycle.onDispose(() => {
      clearInterval(timer)
      nodes.clear()
    })
    api.slots.register({
      order: 100,
      slots: {
        home_bottom: () => make("home"),
        session_prompt_right: () => make("session"),
        sidebar_footer: () => make("sidebar"),
      },
    })
  },
}
