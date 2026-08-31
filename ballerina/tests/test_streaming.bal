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

const SSE_BASE_URL = "http://localhost:8082/sse";

isolated function streamingProvider(string scenario) returns ModelProvider|ai:Error =>
    new (API_KEY, "openai/gpt-5", string `${SSE_BASE_URL}/${scenario}`);

// Collects the text of a chunk stream, so a test asserts on the assembled answer rather
// than on chunk bookkeeping.
isolated function collectContent(stream<ai:ChatCompletionChunk, ai:Error?> chunks) returns string|ai:Error {
    string content = "";
    while true {
        record {|ai:ChatCompletionChunk value;|}|ai:Error? next = chunks.next();
        if next is () {
            return content;
        }
        if next is ai:Error {
            return next;
        }
        foreach ai:ChatCompletionChunkChoice choice in next.value.choices {
            content += choice.delta.content ?: "";
        }
    }
}

@test:Config
function testChatStreamAssemblesTextAndUsage() returns error? {
    ModelProvider provider = check streamingProvider("text");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});

    string content = "";
    ai:FinishReason? finishReason = ();
    ai:CompletionTokenUsage? usage = ();
    int chunkCount = 0;

    check from ai:ChatCompletionChunk chunk in chunks
        do {
            chunkCount += 1;
            foreach ai:ChatCompletionChunkChoice choice in chunk.choices {
                content += choice.delta.content ?: "";
                ai:FinishReason? reason = choice.finishReason;
                if reason is ai:FinishReason {
                    finishReason = reason;
                }
            }
            ai:CompletionTokenUsage? chunkUsage = chunk?.usage;
            if chunkUsage is ai:CompletionTokenUsage {
                usage = chunkUsage;
            }
        };

    test:assertEquals(content, "Hello world");
    test:assertEquals(finishReason, ai:STOP);
    test:assertEquals(chunkCount, 4, "The [DONE] sentinel must not surface as a chunk");
    test:assertEquals(usage, <ai:CompletionTokenUsage>{
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15
    });
}

@test:Config
function testChatStreamCarriesIdAndModel() returns error? {
    ModelProvider provider = check streamingProvider("text");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});
    record {|ai:ChatCompletionChunk value;|}|ai:Error? first = chunks.next();
    if first !is record {|ai:ChatCompletionChunk value;|} {
        test:assertFail("Expected a first chunk");
    }
    test:assertEquals(first.value?.id, "gen-1");
    test:assertEquals(first.value?.model, "openai/gpt-5");
    test:assertEquals(first.value.choices[0].delta.role, ai:ASSISTANT);
    check chunks.close();
}

// Regression test for the leaner envelopes some upstream providers send: only `choices`
// is guaranteed, so requiring `id`/`object`/`created`/`model` would drop the whole chunk.
@test:Config
function testChatStreamAcceptsMinimalEnvelope() returns error? {
    ModelProvider provider = check streamingProvider("minimal");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});
    test:assertEquals(check collectContent(chunks), "Lean envelope");
}

@test:Config
function testChatStreamAccumulatesToolCallFragments() returns error? {
    ModelProvider provider = check streamingProvider("tools");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});

    map<string> names = {};
    map<string> arguments = {};
    map<string> ids = {};
    ai:FinishReason? finishReason = ();

    check from ai:ChatCompletionChunk chunk in chunks
        do {
            foreach ai:ChatCompletionChunkChoice choice in chunk.choices {
                ai:FinishReason? reason = choice.finishReason;
                if reason is ai:FinishReason {
                    finishReason = reason;
                }
                ai:ToolCallChunk[]? toolCalls = choice.delta.toolCalls;
                if toolCalls is () {
                    continue;
                }
                foreach ai:ToolCallChunk toolCall in toolCalls {
                    string key = toolCall.index.toString();
                    string? id = toolCall?.id;
                    if id is string {
                        ids[key] = id;
                    }
                    ai:FunctionCallChunk? 'function = toolCall?.'function;
                    if 'function is () {
                        continue;
                    }
                    string? name = 'function?.name;
                    if name is string {
                        names[key] = name;
                    }
                    arguments[key] = (arguments[key] ?: "") + ('function?.arguments ?: "");
                }
            }
        };

    test:assertEquals(finishReason, ai:TOOL_CALLS);
    test:assertEquals(ids, {"0": "call_a", "1": "call_b"});
    test:assertEquals(names, {"0": "getWeather", "1": "getTime"});
    // Fragments of call 0 arrive either side of call 1, so they must be correlated by index.
    test:assertEquals(arguments, {"0": string `{"city":"Colombo"}`, "1": "{}"});
}

@test:Config
function testChatStreamExposesReasoning() returns error? {
    ModelProvider provider = check streamingProvider("reasoning");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "What is 6 times 7?"});

    string reasoning = "";
    string content = "";
    check from ai:ChatCompletionChunk chunk in chunks
        do {
            foreach ai:ChatCompletionChunkChoice choice in chunk.choices {
                reasoning += choice.delta.reasoning ?: "";
                content += choice.delta.content ?: "";
            }
        };

    test:assertEquals(reasoning, "Let me think about it");
    test:assertEquals(content, "42");
}

// OpenRouter normalizes upstream failures to a finish reason of "error", which is outside
// the `ai:FinishReason` set; it must map to `()` rather than failing the stream.
@test:Config
function testChatStreamMapsUnknownFinishReasonToNil() returns error? {
    ModelProvider provider = check streamingProvider("unknownfinish");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});

    string content = "";
    check from ai:ChatCompletionChunk chunk in chunks
        do {
            foreach ai:ChatCompletionChunkChoice choice in chunk.choices {
                content += choice.delta.content ?: "";
                test:assertEquals(choice.finishReason, (), "An unrecognized finish reason must map to ()");
            }
        };
    test:assertEquals(content, "Partial");
}

@test:Config
function testChatStreamSkipsKeepAliveFrames() returns error? {
    ModelProvider provider = check streamingProvider("keepalive");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});
    test:assertEquals(check collectContent(chunks), "After keep-alive");
}

// A generation cut short must surface as an error. Skipping the error frame would hand the
// caller "Partial" as though it were the whole answer.
@test:Config
function testChatStreamSurfacesMidStreamError() returns error? {
    ModelProvider provider = check streamingProvider("midstreamerror");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});

    string|ai:Error content = collectContent(chunks);
    if content !is ai:Error {
        test:assertFail(string `Expected a mid-stream error, got "${content}"`);
    }
    test:assertTrue(content.message().includes("Rate limit exceeded"),
            string `Expected the upstream message, got "${content.message()}"`);
}

@test:Config
function testChatStreamSurfacesMalformedFrame() returns error? {
    ModelProvider provider = check streamingProvider("malformed");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});

    string|ai:Error content = collectContent(chunks);
    if content !is ai:Error {
        test:assertFail(string `Expected a malformed-frame error, got "${content}"`);
    }
    test:assertTrue(content is ai:LlmInvalidResponseError,
            "A malformed frame must surface as an ai:LlmInvalidResponseError");
}

// The status code must be read before the SSE stream is opened, or OpenRouter's own message
// is lost and the caller sees only that the stream could not be opened.
@test:Config
function testChatStreamReportsUnauthorized() returns error? {
    ModelProvider provider = check streamingProvider("unauthorized");
    stream<ai:ChatCompletionChunk, ai:Error?>|ai:Error chunks =
        provider->chatStream({role: ai:USER, content: "hi"});
    if chunks !is ai:Error {
        test:assertFail("Expected a 401 to fail the request");
    }
    test:assertTrue(chunks.message().includes("401"), chunks.message());
    test:assertTrue(chunks.message().includes("No auth credentials found"), chunks.message());
}

@test:Config
function testChatStreamReportsInsufficientCredits() returns error? {
    ModelProvider provider = check streamingProvider("insufficientcredits");
    stream<ai:ChatCompletionChunk, ai:Error?>|ai:Error chunks =
        provider->chatStream({role: ai:USER, content: "hi"});
    if chunks !is ai:Error {
        test:assertFail("Expected a 402 to fail the request");
    }
    test:assertTrue(chunks.message().includes("Insufficient credits"), chunks.message());
}

@test:Config
function testChatStreamReportsPlainTextErrorBody() returns error? {
    ModelProvider provider = check streamingProvider("plaintexterror");
    stream<ai:ChatCompletionChunk, ai:Error?>|ai:Error chunks =
        provider->chatStream({role: ai:USER, content: "hi"});
    if chunks !is ai:Error {
        test:assertFail("Expected a 502 to fail the request");
    }
    test:assertTrue(chunks.message().includes("upstream provider unavailable"), chunks.message());
}

@test:Config
function testChatStreamSendsAttributionHeaders() returns error? {
    ModelProvider provider = check new (API_KEY, "openai/gpt-5", string `${SSE_BASE_URL}/attribution`,
            siteUrl = "https://example.com", siteName = "Example App");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});
    _ = check collectContent(chunks);
}

@test:Config
function testGenerateStreamYieldsTextFragments() returns error? {
    ModelProvider provider = check streamingProvider("text");
    stream<string, ai:Error?> fragments = check provider->generateStream(`Say hello`);

    string[] collected = [];
    check from string fragment in fragments
        do {
            collected.push(fragment);
        };

    // Only non-empty content fragments are yielded; the finish-reason and usage-only
    // chunks carry no text and must be skipped rather than emitted as "".
    test:assertEquals(collected, ["Hello", " world"]);
}

@test:Config
function testGenerateStreamRejectsNonStringType() returns error? {
    ModelProvider provider = check streamingProvider("text");
    stream<int, ai:Error?>|ai:Error fragments = provider->generateStream(`Rate this out of 10`);
    if fragments !is ai:Error {
        test:assertFail("Expected generateStream to reject a non-string expected type");
    }
    test:assertTrue(fragments.message().includes("supports only 'string'"), fragments.message());
}

// The stream is closable part-way through, which is what an early `break` in a consumer does.
@test:Config
function testChatStreamCloseIsIdempotent() returns error? {
    ModelProvider provider = check streamingProvider("text");
    stream<ai:ChatCompletionChunk, ai:Error?> chunks =
        check provider->chatStream({role: ai:USER, content: "hi"});
    record {|ai:ChatCompletionChunk value;|}|ai:Error? first = chunks.next();
    test:assertTrue(first is record {|ai:ChatCompletionChunk value;|});
    check chunks.close();
    check chunks.close();
}
