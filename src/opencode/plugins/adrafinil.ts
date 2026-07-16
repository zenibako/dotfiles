import type { Plugin, PluginInput } from "@opencode-ai/plugin"
import type { Event } from "@opencode-ai/sdk"

type BunShell = PluginInput["$"]

const EVENT_ACQUIRE = [
  "session.status",
  "session.updated",
  "session.created",
] as const

const EVENT_RELEASE = [
  "session.idle",
] as const

const ACQUIRE_ERROR_PATTERNS = [
  { regex: /acquire refused:\s*(.+)/, kind: "refused" as const },
  { regex: /daemon not running/, kind: "daemon_unreachable" as const },
  { regex: /acquire failed \((.+)\)/, kind: "transport_error" as const },
]

interface ClassifiedError {
  kind: "refused" | "daemon_unreachable" | "transport_error"
  message: string
}

interface AdrafinilError {
  ok: false
  action: "acquire"
  sessionId: string
  error: ClassifiedError
  status: unknown
  timestamp: string
}

function classifyAcquireError(stderr: string): ClassifiedError | null {
  for (const { regex, kind } of ACQUIRE_ERROR_PATTERNS) {
    const match = stderr.match(regex)
    if (match) {
      return { kind, message: match[1]?.trim() ?? stderr.trim() }
    }
  }
  return null
}

async function fetchStatusJson($: BunShell): Promise<unknown> {
  try {
    const out = await $`adrafinil status --json`.quiet().text()
    return JSON.parse(out)
  } catch {
    return null
  }
}

function emitErrorJson(result: AdrafinilError): void {
  console.log(JSON.stringify(result))
}

function sessionIdFromEvent(event: Event): string | undefined {
  const props = event.properties as Record<string, unknown>
  if (typeof props?.info === "object" && props.info !== null) {
    const info = props.info as { id?: string }
    return info.id
  }
  if (typeof props?.sessionID === "string") {
    return props.sessionID
  }
  return undefined
}

export const Adrafinil: Plugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      let adrafinilAction: "acquire" | "release" | undefined
      if (EVENT_ACQUIRE.includes(event.type as typeof EVENT_ACQUIRE[number])) {
        adrafinilAction = "acquire"
      }
      else if (EVENT_RELEASE.includes(event.type as typeof EVENT_RELEASE[number])) {
        adrafinilAction = "release"
      }

      if (!adrafinilAction) {
        return
      }

      const sessionId = sessionIdFromEvent(event)
      if (!sessionId) {
        return
      }

      const output = await $`adrafinil ${adrafinilAction} ${sessionId} --tool opencode`
        .quiet()
        .nothrow()

      if (adrafinilAction === "acquire") {
        const stderr = output.stderr.toString().trim()
        if (stderr) {
          const classified = classifyAcquireError(stderr)
          if (classified) {
            const status = await fetchStatusJson($)
            const result: AdrafinilError = {
              ok: false,
              action: "acquire",
              sessionId,
              error: classified,
              status,
              timestamp: new Date().toISOString(),
            }
            emitErrorJson(result)
            return
          }
        }
      }
    },
  }
}