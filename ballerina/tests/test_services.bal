// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

// Local types used only for deserialising generate() request payloads in the mock service.
type TextContentPart record {
    string text;
};

type ToolFunction record {
    string name;
    string description?;
    map<json> parameters?;
};

type Tool record {
    string 'type;
    ToolFunction 'function;
};

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
                "usage": {"prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30}
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
                "usage": {"prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30}
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
                "usage": {"prompt_tokens": 5, "completion_tokens": 10, "total_tokens": 15}
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
                "usage": {"prompt_tokens": 10, "completion_tokens": 15, "total_tokens": 25}
            };
        }

        return error(string `Unexpected message in chat mock: ${firstContent}`);
    }
}

service /llm on new http:Listener(8080) {
    // Change the payload type to JSON due to https://github.com/ballerina-platform/ballerina-library/issues/8048.
    resource function post openrouter/v1/chat/completions(@http:Payload json payload)
                returns json|error {
        string modelName = check payload.model.ensureType();
        boolean validModel = modelName == "openai/gpt-5"
                || modelName == "anthropic/claude-sonnet-4"
                || modelName == "deepseek/deepseek-chat";
        test:assertTrue(validModel, string `Unexpected model in request: ${modelName}`);
        map<json>[] messages = check (check payload.messages).cloneWithType();
        map<json> message = messages[0];

        json rawContentJson = message["content"];
        map<json>[] content;
        if rawContentJson is string {
            content = [{"type": "text", "text": rawContentJson}];
        } else if rawContentJson is json[] {
            content = check rawContentJson.cloneWithType();
        } else {
            return error("Expected content in the payload");
        }

        TextContentPart initialTextContent = check content[0].cloneWithType();
        string initialText = initialTextContent.text;
        test:assertEquals(content.toJson(), getExpectedContentParts(initialText).toJson(),
                string `Test failed for prompt with initial content, ${initialText}`);
        test:assertEquals(message["role"], "user");
        Tool[]? tools = check (check payload.tools).cloneWithType();
        if tools is () || tools.length() == 0 {
            test:assertFail("No tools in the payload");
        }

        map<json>? parameters = tools[0].'function.parameters;
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
