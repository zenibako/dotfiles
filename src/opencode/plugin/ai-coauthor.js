// Injects AI_CO_AUTHOR into every bash tool environment, derived from the
// model actually driving the session (captured from chat.params). The zshrc
// jjc/jjd/gitc helpers and the local-dev agent prompt append this value as a
// Co-authored-by trailer; without it they fall back to the placeholder
// "AI Model <ai@example.com>" (seen in commits ed1c424, fd4516d, 91f1f80).
//
// Identity format follows AGENTS.md's model-identity mapping:
//   opencode-go/glm-5.2  -> GLM <glm-5.2@ai>
//   lmstudio/qwen3.5-9b  -> Qwen <qwen3.5-9b@ai>
//   openai/gpt-5.4       -> GPT <gpt-5.4@ai>
const sessionModel = new Map() // sessionID -> modelID

function identity(modelID) {
  const family = (modelID.match(/^[a-zA-Z]+/) || ["AI"])[0]
  const display = family.length <= 3 ? family.toUpperCase() : family[0].toUpperCase() + family.slice(1)
  return `${display} <${modelID}@ai>`
}

export const AiCoauthor = async () => {
  return {
    "chat.params": async (input, _output) => {
      const modelID = input.model?.api?.id ?? input.model?.info?.id ?? input.model?.id
      if (input.sessionID && typeof modelID === "string" && modelID) {
        sessionModel.set(input.sessionID, modelID)
      }
    },
    "shell.env": async (input, output) => {
      const modelID = input.sessionID && sessionModel.get(input.sessionID)
      if (modelID) output.env.AI_CO_AUTHOR = identity(modelID)
    },
  }
}
