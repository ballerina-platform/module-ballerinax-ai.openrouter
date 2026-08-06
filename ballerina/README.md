## Overview

The `ai.openrouter` module provides `ModelProvider` and `EmbeddingProvider` implementations for the [`ballerina/ai`](https://central.ballerina.io/ballerina/ai/latest) agent framework, backed by [OpenRouter](https://openrouter.ai)'s unified API. Use it to drive 200+ LLMs from OpenAI, Anthropic, Google, Meta, Mistral, and other providers through a single OpenRouter endpoint in your Ballerina AI agents.

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
