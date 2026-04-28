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

import ballerina/ai;
import ballerina/test;

const SERVICE_URL = "http://localhost:8080/llm/openrouter/v1";
const API_KEY = "not-a-real-api-key";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the LLM as the expected type. Retrying and/or validating the prompt could fix the response.";

final ModelProvider provider = check new (API_KEY, "openai/gpt-5", SERVICE_URL);
final ModelProvider anthropicProvider = check new (API_KEY, "anthropic/claude-sonnet-4", SERVICE_URL);
final ModelProvider deepseekProvider = check new (API_KEY, "deepseek/deepseek-chat", SERVICE_URL);

@test:Config
function testGenerateMethodWithBasicReturnType() returns ai:Error? {
    int|error rating = provider->generate(`Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithBasicArrayReturnType() returns ai:Error? {
    int[]|error rating = provider->generate(`Evaluate this blogs out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}

        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, [9, 1]);
}

@test:Config
function testGenerateMethodWithRecordReturnType() returns error? {
    Review|error result = provider->generate(`Please rate this blog out of ${"10"}.
        Title: ${blog2.title}
        Content: ${blog2.content}`);
    test:assertEquals(result, check review.fromJsonStringWithType(Review));
}

@test:Config
function testGenerateMethodWithTextDocument() returns ai:Error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    int maxScore = 10;

    int|error rating = provider->generate(`How would you rate this ${"blog"} content out of ${maxScore}. ${blog}.`);
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithImageDocumentWithBinaryData() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData
    };

    string|error description = provider->generate(`Describe the following image. ${img}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "https://example.com/image.jpg",
        metadata: {
            mimeType: "image/jpg"
        }
    };

    string|error description = provider->generate(`Describe the image. ${img}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithInvalidUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "This-is-not-a-valid-url"
    };

    string|ai:Error description = provider->generate(`Please describe the image. ${img}.`);
    test:assertTrue(description is ai:Error);

    string actualErrorMessage = (<ai:Error>description).message();
    string expectedErrorMessage = "Must be a valid URL";
    test:assertTrue((<ai:Error>description).message().includes("Must be a valid URL"),
            string `expected '${expectedErrorMessage}', found ${actualErrorMessage}`);
}

@test:Config
function testGenerateMethodWithImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:ImageDocument img2 = {
        content: "https://example.com/image.jpg"
    };

    string[]|error descriptions = provider->generate(
        `Describe the following ${"2"} images. ${<ai:ImageDocument[]>[img, img2]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample image description."]);
}

@test:Config
function testGenerateMethodWithTextAndImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = provider->generate(
        `Please describe the following image and the doc. ${<ai:Document[]>[img, blog]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithImageDocumentsandTextDocuments() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = provider->generate(
        `${"Describe"} the following ${"text"} ${"document"} and image document. ${img}${blog}`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithTextChunk() returns error? {
    ai:TextChunk chunk = {content: string `Title: ${blog1.title} Content: ${blog1.content}`};
    ai:TextChunk[] chunks = [chunk, chunk];
    int maxScore = 10;

    int rating = check provider->generate(`How would you rate this text chunk content out of ${maxScore}. ${chunk}.`);
    test:assertEquals(rating, 4);

    Review r = check review.fromJsonStringWithType(Review);
    Review[] result = check provider->generate(`How would you rate these text chunks out of ${maxScore}. ${chunks}. Thank you!`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithAudioDocument() returns ai:Error? {
    ai:AudioDocument aud = {
        content: sampleBinaryData,
        metadata: {
            "format": "mp3"
        }
    };

    string[]|error descriptions = provider->generate(`What is the content in this document. ${aud}.`);
    test:assertTrue(descriptions is error);
    test:assertTrue((<error>descriptions).message().includes("Only text and image documents are supported."));
}

@test:Config
function testGenerateMethodWithUnsupportedDocument() returns ai:Error? {
    ai:FileDocument doc = {
        content: "dummy-data"
    };

    string[]|error descriptions = provider->generate(`What is the content in this document. ${doc}.`);
    test:assertTrue(descriptions is error);
    test:assertTrue((<error>descriptions).message().includes("Only text and image documents are supported."));
}

@test:Config
function testGenerateMethodWithStringUnionNull() returns error? {
    string? result = check provider->generate(`Give me a random joke`);
    test:assertTrue(result is string);
}

@test:Config
function testAnthropicGenerateWithBasicReturnType() returns ai:Error? {
    int|error rating = anthropicProvider->generate(`Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, 4);
}

@test:Config
function testAnthropicGenerateWithRecordReturnType() returns error? {
    Review|error result = anthropicProvider->generate(`Please rate this blog out of ${"10"}.
        Title: ${blog2.title}
        Content: ${blog2.content}`);
    test:assertEquals(result, check review.fromJsonStringWithType(Review));
}

@test:Config
function testDeepSeekGenerateWithBasicReturnType() returns ai:Error? {
    int|error rating = deepseekProvider->generate(`Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, 4);
}

@test:Config
function testDeepSeekGenerateWithStringUnionNull() returns error? {
    string? result = check deepseekProvider->generate(`Give me a random joke`);
    test:assertTrue(result is string);
}

@test:Config
function testChatMethod() returns ai:Error? {
    ModelProvider chatProvider = check new (API_KEY, "openai/gpt-5", "http://localhost:9999");
    ai:ChatMessage[] messages = [
        {role: ai:USER, content: "Hello, how are you?"}
    ];
    // This will fail at HTTP level since the chat test to a port where nothing is listening
    //(preserves original intent: "fails at HTTP level")
    ai:ChatAssistantMessage|ai:Error response = chatProvider->chat(messages, []);
    test:assertTrue(response is ai:Error);
}

// ── chat() + tools tests ─────────────────────────────────────────────────────

const CHAT_MOCK_SERVICE_URL = "http://localhost:8081/llm/openrouter/v1";

final ai:ChatCompletionFunctions getWeatherTool = {
    name: "get_weather",
    description: "Get the current weather for a city",
    parameters: {
        "type": "object",
        "properties": {
            "city": {"type": "string", "description": "The city name"}
        },
        "required": ["city"]
    }
};

final ai:ChatCompletionFunctions bookFlightTool = {
    name: "book_flight",
    description: "Book a flight to a destination",
    parameters: {
        "type": "object",
        "properties": {
            "destination": {"type": "string", "description": "The destination city"}
        },
        "required": ["destination"]
    }
};

// Model returns legacy `function_call` — existing path in convertResponseToAssistantMessage.
@test:Config
function testChatWithFunctionCallResponse() returns error? {
    ModelProvider chatProvider = check new (API_KEY, "openai/gpt-5", CHAT_MOCK_SERVICE_URL);
    ai:ChatMessage[] messages = [{role: ai:USER, content: "What is the weather in Colombo?"}];

    ai:ChatAssistantMessage|ai:Error response = chatProvider->chat(messages, [getWeatherTool]);
    test:assertTrue(response is ai:ChatAssistantMessage,
            string `Expected ChatAssistantMessage but got: ${response is ai:Error ? (<ai:Error>response).message() : ""}`);

    ai:ChatAssistantMessage msg = check response;
    ai:FunctionCall[]? toolCalls = msg.toolCalls;
    test:assertNotEquals(toolCalls, (), "toolCalls must be populated from function_call response");

    ai:FunctionCall call = (<ai:FunctionCall[]>toolCalls)[0];
    test:assertEquals(call.name, "get_weather");
    test:assertEquals(call.arguments["city"], "Colombo");
}

// Model returns modern `tool_calls` — new path added by the tool_calls fix.
@test:Config
function testChatWithToolCallsResponse() returns error? {
    ModelProvider chatProvider = check new (API_KEY, "openai/gpt-5", CHAT_MOCK_SERVICE_URL);
    ai:ChatMessage[] messages = [{role: ai:USER, content: "Book a flight to London"}];

    ai:ChatAssistantMessage|ai:Error response = chatProvider->chat(messages, [bookFlightTool]);
    test:assertTrue(response is ai:ChatAssistantMessage,
            string `Expected ChatAssistantMessage but got: ${response is ai:Error ? (<ai:Error>response).message() : ""}`);

    ai:ChatAssistantMessage msg = check response;
    ai:FunctionCall[]? toolCalls = msg.toolCalls;
    test:assertNotEquals(toolCalls, (), "toolCalls must be populated from tool_calls response");

    ai:FunctionCall call = (<ai:FunctionCall[]>toolCalls)[0];
    test:assertEquals(call.name, "book_flight");
    test:assertEquals(call.arguments["destination"], "London");
}

// Model ignores tools and returns plain text — must get a meaningful LlmInvalidResponseError.
@test:Config
function testChatToolsIgnoredByModel() returns error? {
    ModelProvider chatProvider = check new (API_KEY, "openai/gpt-5", CHAT_MOCK_SERVICE_URL);
    ai:ChatMessage[] messages = [{role: ai:USER, content: "Summarize this text"}];

    ai:ChatAssistantMessage|ai:Error response = chatProvider->chat(messages, [getWeatherTool]);
    test:assertTrue(response is ai:LlmInvalidResponseError,
            string `Expected LlmInvalidResponseError but got: ${response is ai:Error ? (<ai:Error>response).message() : "success"}`);

    string errMsg = (<ai:Error>response).message();
    test:assertTrue(errMsg.includes("openai/gpt-5"), "Error must name the model");
    test:assertTrue(errMsg.includes("1"), "Error must state how many tools were provided");
    test:assertTrue(errMsg.includes("finish_reason: 'stop'"), "Error must include finish_reason from the response");
}

// Model returns plain text with no tool call — toolCalls must be nil.
@test:Config
function testChatWithTextOnlyResponse() returns error? {
    ModelProvider chatProvider = check new (API_KEY, "openai/gpt-5", CHAT_MOCK_SERVICE_URL);
    ai:ChatMessage[] messages = [{role: ai:USER, content: "Hello"}];

    ai:ChatAssistantMessage|ai:Error response = chatProvider->chat(messages, []);
    test:assertTrue(response is ai:ChatAssistantMessage,
            string `Expected ChatAssistantMessage but got: ${response is ai:Error ? (<ai:Error>response).message() : ""}`);

    ai:ChatAssistantMessage msg = check response;
    test:assertEquals(msg.content, "Hello! How can I help you today?");
    test:assertEquals(msg.toolCalls, ());
}

// ── EmbeddingProvider tests ──────────────────────────────────────────────────

final EmbeddingProvider embeddingProvider = check new (API_KEY, "openai/text-embedding-3-small", SERVICE_URL);

@test:Config
function testEmbedWithTextChunk() returns error? {
    ai:TextChunk chunk = {'type: "text-chunk", content: "Hello, world!"};
    ai:Embedding result = check embeddingProvider->embed(chunk);
    test:assertTrue(result is float[]);
    test:assertEquals((<float[]>result).length(), 3);
}

@test:Config
function testEmbedWithTextDocument() returns error? {
    ai:TextDocument doc = {'type: "text", content: "This is a text document."};
    ai:Embedding result = check embeddingProvider->embed(doc);
    test:assertTrue(result is float[]);
    test:assertEquals((<float[]>result).length(), 3);
}

@test:Config
function testBatchEmbedWithTextChunks() returns error? {
    ai:TextChunk[] chunks = [
        {'type: "text-chunk", content: "First chunk."},
        {'type: "text-chunk", content: "Second chunk."}
    ];
    ai:Embedding[] results = check embeddingProvider->batchEmbed(chunks);
    test:assertEquals(results.length(), 2);
    test:assertTrue(results[0] is float[]);
    test:assertTrue(results[1] is float[]);
}

@test:Config
function testBatchEmbedWithTextDocuments() returns error? {
    ai:TextDocument[] docs = [
        {'type: "text", content: "Document one."},
        {'type: "text", content: "Document two."},
        {'type: "text", content: "Document three."}
    ];
    ai:Embedding[] results = check embeddingProvider->batchEmbed(docs);
    test:assertEquals(results.length(), 3);
}

@test:Config
function testEmbedWithUnsupportedChunkType() {
    ai:Chunk unsupportedChunk = {'type: "custom", content: "some data"};
    ai:Embedding|ai:Error result = embeddingProvider->embed(unsupportedChunk);
    test:assertTrue(result is ai:Error);
    test:assertTrue((<ai:Error>result).message().includes("Unsupported chunk type"));
}

@test:Config
function testBatchEmbedWithUnsupportedChunkType() {
    ai:TextChunk validChunk = {'type: "text-chunk", content: "valid"};
    ai:Chunk invalidChunk = {'type: "custom", content: "invalid"};
    ai:Embedding[]|ai:Error result = embeddingProvider->batchEmbed([validChunk, invalidChunk]);
    test:assertTrue(result is ai:Error);
    test:assertTrue((<ai:Error>result).message().includes("Unsupported chunk type"));
}

@test:Config
function testEmbedConnectionError() {
    EmbeddingProvider|error badProvider = new (API_KEY, "openai/text-embedding-3-small", "http://localhost:9999");
    if badProvider is error {
        test:assertFail("Provider initialization should succeed");
    }
    ai:Embedding|ai:Error result = badProvider->embed({'type: "text-chunk", content: "test"});
    test:assertTrue(result is ai:Error);
}
