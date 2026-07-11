import { execFileSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { basename } from "node:path"
import type { HookAPI } from "@oh-my-pi/pi-coding-agent"

const esc = "\x1b["
const reset = `${esc}0m`

function gitBranch(): string {
  try {
    return execFileSync("git", ["branch", "--show-current"], { encoding: "utf8", timeout: 500 }).trim() || "detached"
  } catch {
    return "no-git"
  }
}

function activeModes(): string {
  try {
    const file = `${process.env.XDG_CONFIG_HOME || `${process.env.HOME}/.config`}/aicli-ultimate/modes`
    const text = readFileSync(file, "utf8")
    const modes = []
    if (/^caveman=(?!off)/m.test(text)) modes.push("caveman")
    if (/^ponytail=(?!off)/m.test(text)) modes.push("ponytail")
    return modes.join("+") || "standard"
  } catch {
    return "standard"
  }
}

function render(): string {
  const dir = basename(process.cwd()) || "~"
  const branch = gitBranch()
  const clock = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  if (process.env.NO_COLOR) return `OMP · ${dir} ·  ${branch} · ${activeModes()} · ${clock}`
  return [
    `${esc}38;2;26;27;38;48;2;122;162;247m OMP ${reset}`,
    `${esc}38;2;122;162;247m${reset}`,
    `${esc}38;2;125;207;255m ${dir} ${reset}`,
    `${esc}38;2;86;95;137m${reset}`,
    `${esc}38;2;158;206;106m  ${branch} ${reset}`,
    `${esc}38;2;86;95;137m${reset}`,
    `${esc}38;2;187;154;247m ${activeModes()} ${reset}`,
    `${esc}38;2;86;95;137m ${clock}${reset}`,
  ].join("")
}

export default function (pi: HookAPI) {
  let timer: ReturnType<typeof setInterval> | undefined
  let current: any
  const update = () => current?.ui.setStatus("aicli-ultimate", render())

  pi.on("session_start", async (_event, ctx) => {
    current = ctx
    update()
    timer ??= setInterval(update, 10_000)
  })
  pi.on("session_switch", async (_event, ctx) => {
    current = ctx
    update()
  })
  pi.on("turn_start", async (_event, ctx) => {
    current = ctx
    update()
  })
  pi.on("turn_end", async (_event, ctx) => {
    current = ctx
    update()
  })
  pi.on("session_shutdown", async (_event, ctx) => {
    if (timer) clearInterval(timer)
    timer = undefined
    ctx.ui.setStatus("aicli-ultimate", undefined)
  })
}
