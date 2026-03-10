// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/test;
import ballerinax/openai.chat;

// ── Chat mock service (port 8081) ────────────────────────────────────────────
// Used by chat() tests. Routes by first user message content.
// Returns either a legacy `function_call` response, a modern `tool_calls`
// response, or a plain text response depending on the prompt.
service /llm on new http:Listener(8081) {
    resource function post openrouter/v1/chat/completions(@http:Payload json payload)
            returns json|error {
        json[] messages = check (check payload.messages).cloneWithType();
        map<json> firstMessage = check messages[0].cloneWithType();
        string firstContent = check firstMessage["content"].ensureType();

        if firstContent == "What is the weather in Colombo?" {
            // Legacy function_call response
            return {
                "id": "chat-fc-id",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "openai/gpt-5",
                "choices": [{
                    "finish_reason": "function_call",
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": (),
                        "function_call": {
                            "name": "get_weather",
                            "arguments": "{\"city\": \"Colombo\"}"
                        }
                    }
                }],
                "usage": {"prompt_tokens": 20, "completion_tokens": 10}
            };
        }

        if firstContent == "Book a flight to London" {
            // Modern tool_calls response
            return {
                "id": "chat-tc-id",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "openai/gpt-5",
                "choices": [{
                    "finish_reason": "tool_calls",
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": (),
                        "tool_calls": [{
                            "id": "call_abc123",
                            "type": "function",
                            "function": {
                                "name": "book_flight",
                                "arguments": "{\"destination\": \"London\"}"
                            }
                        }]
                    }
                }],
                "usage": {"prompt_tokens": 20, "completion_tokens": 10}
            };
        }

        if firstContent == "Hello" {
            // Plain text — no tool call
            return {
                "id": "chat-text-id",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "openai/gpt-5",
                "choices": [{
                    "finish_reason": "stop",
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello! How can I help you today?"
                    }
                }],
                "usage": {"prompt_tokens": 5, "completion_tokens": 10}
            };
        }

        if firstContent == "Summarize this text" {
            // Model ignores tools and responds with plain text
            return {
                "id": "chat-ignore-id",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "openai/gpt-5",
                "choices": [{
                    "finish_reason": "stop",
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Here is the summary..."
                    }
                }],
                "usage": {"prompt_tokens": 10, "completion_tokens": 15}
            };
        }

        return error(string `Unexpected message in chat mock: ${firstContent}`);
    }
}

service /llm on new http:Listener(8080) {
    // Change the payload type to JSON due to https://github.com/ballerina-platform/ballerina-library/issues/8048.
    resource function post openrouter/v1/chat/completions(@http:Payload json payload)
                returns chat:CreateChatCompletionResponse|error {
        string modelName = check payload.model.ensureType();
        boolean validModel = modelName == "openai/gpt-5"
                || modelName == "anthropic/claude-sonnet-4"
                || modelName == "deepseek/deepseek-chat";
        test:assertTrue(validModel, string `Unexpected model in request: ${modelName}`);
        chat:ChatCompletionRequestMessage[] messages = check (check payload.messages).fromJsonWithType();
        chat:ChatCompletionRequestMessage message = messages[0];

        string|chat:ChatCompletionRequestUserMessageContentPart[]|() rawContent = check message["content"].ensureType();
        chat:ChatCompletionRequestUserMessageContentPart[]? content;
        if rawContent is string {
            content = [{'type: "text", text: rawContent}];
        } else {
            content = rawContent;
        }
        if content is () {
            test:assertFail("Expected content in the payload");
        }

        chat:ChatCompletionRequestUserMessageContentPart initialContentPart = content[0];
        TextContentPart initialTextContent = check initialContentPart.ensureType();
        string initialText = initialTextContent.text;
        test:assertEquals(content.toJson(), getExpectedContentParts(initialText).toJson(),
                string `Test failed for prompt with initial content, ${initialText}`);
        test:assertEquals(message.role, "user");
        chat:ChatCompletionTool[]? tools = check (check payload.tools).fromJsonWithType();
        if tools is () || tools.length() == 0 {
            test:assertFail("No tools in the payload");
        }

        map<json>? parameters = check tools[0].'function?.parameters.toJson().cloneWithType();
        if parameters is () {
            test:assertFail("No parameters in the expected tool");
        }

        test:assertEquals(parameters, getExpectedParameterSchema(initialText),
                string `Test failed for prompt with initial content, ${initialText}`);
        return getTestServiceResponse(initialText);
    }

    resource function post openrouter/v1/embeddings(@http:Payload json payload) returns json|error {
        string model = check payload.model.ensureType();
        json inputJson = check payload.input;

        json[] data;
        if inputJson is string {
            data = [{"object": "embedding", "embedding": [0.1, 0.2, 0.3], "index": 0}];
        } else {
            json[] inputs = check inputJson.ensureType();
            data = [];
            foreach int i in 0 ..< inputs.length() {
                data.push({"object": "embedding", "embedding": [0.1, 0.2, 0.3], "index": i});
            }
        }

        return {
            "object": "list",
            "data": data,
            "model": model,
            "usage": {"prompt_tokens": 5, "total_tokens": 5}
        };
    }
}
