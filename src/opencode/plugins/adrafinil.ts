export const Adrafinil = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.created") await $`"/Applications/Adrafinil.app/Contents/Helpers/adrafinil" acquire ${event.properties.info.id} --tool opencode`
    }
  }
}