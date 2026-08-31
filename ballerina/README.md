## Overview

This module offers APIs for connecting with 200+ Large Language Models (LLMs) through the
[OpenRouter](https://openrouter.ai) unified API, including models from OpenAI, Anthropic,
Google, Meta, Mistral, and many more providers.

## Prerequisites

Before using this module in your Ballerina application, you must first obtain an OpenRouter API key.

- Create an [OpenRouter account](https://openrouter.ai/signup).
- Obtain an API key from [https://openrouter.ai/keys](https://openrouter.ai/keys).

## Quickstart

To use the `ai.openrouter` module in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `ai.openrouter` module.

```ballerina
import ballerinax/ai.openrouter;
```

### Step 2: Initialize the Model Provider

Here's how to initialize the Model Provider:

```ballerina
import ballerina/ai;
import ballerinax/ai.openrouter;

final ai:ModelProvider openRouterModel = check new openrouter:ModelProvider(
    "openRouterApiKey",
    modelType = "anthropic/claude-3.5-sonnet"
);
```

### Step 3: Invoke chat completion

```ballerina
ai:ChatMessage[] chatMessages = [{role: "user", content: "hi"}];
ai:ChatAssistantMessage response = check openRouterModel->chat(chatMessages, tools = []);

chatMessages.push(response);
```

### Step 4: Generate typed output

```ballerina
type Sentiment record {|
    string label;
    decimal score;
|};

@ai:JsonSchema {
    "type": "object",
    "required": ["label", "score"],
    "properties": {
        "label": {"type": "string", "enum": ["positive", "neutral", "negative"]},
        "score": {"type": "number"}
    }
}
type SentimentType Sentiment;

Sentiment|error result = openRouterModel->generate(
    `Analyze the sentiment of: "I love this product!"`
);
```

### Step 5: Stream the response

To show the answer as it is produced rather than waiting for all of it, use `generateStream`
for the generated text, or `chatStream` for the raw chunks:

```ballerina
stream<string, ai:Error?> fragments = check openRouterModel->generateStream(`Tell me about Ballerina`);
check from string fragment in fragments
    do {
        io:print(fragment);
    };
```

Each `ai:ChatCompletionChunk` from `chatStream` carries text, reasoning and tool-call fragments,
and the last one carries the finish reason and the token usage. Tool-call fragments are
correlated by `index`, so a caller accumulates the arguments of each call across chunks.

`generateStream` supports only `string`, since a partial generation is a valid value only for
`string`; use `generate` for structured output. It also streams the answer text only - on a
reasoning model the chain-of-thought that precedes the answer is dropped. To observe it, use
`chatStream` and read `delta.reasoning`:

```ballerina
final ai:ModelProvider reasoner = check new openrouter:ModelProvider(
    "openRouterApiKey",
    modelType = "deepseek/deepseek-r1"
);
stream<ai:ChatCompletionChunk, ai:Error?> chunks =
    check reasoner->chatStream({role: ai:USER, content: "What is 6 times 7?"});
check from ai:ChatCompletionChunk chunk in chunks
    do {
        foreach ai:ChatCompletionChunkChoice choice in chunk.choices {
            io:print(choice.delta.reasoning ?: choice.delta.content ?: "");
        }
    };
```

Because OpenRouter fronts many upstream providers, streaming support and the shape of a
chunk vary by model. Errors the upstream provider reports part-way through a generation
arrive as a mid-stream error frame and surface as an `ai:LlmError` from the stream, so a
truncated answer is never silently presented as a complete one.
