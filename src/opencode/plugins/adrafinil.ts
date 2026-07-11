const EVENT_ACQUIRE = [
  "session.status",
  "session.updated",
  "session.created",
]

const EVENT_RELEASE = [
  "session.idle",
]

export const Adrafinil = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      let adrafinilAction
      if (EVENT_ACQUIRE.includes(event.type)) {
        adrafinilAction = "acquire"
      }
      else if (EVENT_RELEASE.includes(event.type)) {
        adrafinilAction = "release"
      }

      if (!adrafinilAction) {
        return
      }

      await $`adrafinil ${adrafinilAction} ${event.properties.info.id} --tool opencode`
    }
  }
}
