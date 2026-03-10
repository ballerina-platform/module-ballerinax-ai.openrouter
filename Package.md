# Ballerina OpenRouter Model Provider

## Overview

[OpenRouter](https://openrouter.ai) is a unified API gateway that provides access to 200+ Large Language
Models from leading AI providers including OpenAI (GPT-4o, o1), Anthropic (Claude 3.5 Sonnet, Claude 3 Opus),
Google (Gemini Pro, Gemini Flash), Meta (Llama 3.1), Mistral (Mixtral, Mistral Large), and many more —
all through a single OpenAI-compatible API.

The `ballerinax/ai.openrouter` package provides a Ballerina model provider that integrates with the
[Ballerina AI framework](https://central.ballerina.io/ballerina/ai/latest), enabling you to use any
OpenRouter-supported model in your Ballerina AI agents and applications.

## Prerequisites

Before using this module in your Ballerina application, you must first:

1. Create an [OpenRouter account](https://openrouter.ai/signup).
2. Obtain an API key from [https://openrouter.ai/keys](https://openrouter.ai/keys).

## Quickstart

### Step 1: Import the module

```ballerina
import ballerina/ai;
import ballerinax/ai.openrouter;
```

### Step 2: Initialize the Model Provider

```ballerina
// Initialize with Anthropic Claude 3.5 Sonnet via OpenRouter
final ai:ModelProvider model = check new openrouter:ModelProvider(
    apiKey = "<OPENROUTER_API_KEY>",
    modelType = openrouter:ANTHROPIC_CLAUDE_3_5_SONNET,
    siteUrl = "https://my-app.example.com",   // Optional: for OpenRouter attribution
    siteName = "My Ballerina App"              // Optional: for OpenRouter attribution
);
```

### Step 3: Chat with the model

```ballerina
import ballerina/io;

public function main() returns error? {
    ai:ChatMessage[] messages = [
        {role: ai:USER, content: "What are the benefits of functional programming?"}
    ];

    ai:ChatAssistantMessage response = check model->chat(messages, []);
    io:println("Assistant: ", response.content);
}
```
