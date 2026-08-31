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

// Mock Server-Sent Events endpoints backing the streaming tests.
//
// Each scenario gets its own base path so a test can point a provider at exactly the stream
// it wants to exercise: a provider built with `serviceUrl` `.../sse/<scenario>` posts to
// `<scenario>/chat/completions` under this service.
service /sse on new http:Listener(8082) {

    // Plain text answer, ending with a finish-reason chunk and a usage-only chunk.
    resource function post text/chat/completions(@http:Payload json payload)
            returns stream<http:SseEvent, error?>|error {
        test:assertEquals(check payload.'stream, true, "Streaming requests must set 'stream'");
        test:assertEquals(check payload.max_completion_tokens, <decimal>512,
                "Streaming requests must carry the configured token ceiling");
        // OpenRouter deprecated `stream_options.include_usage` and always sends full usage
        // details on the final chunk, so the request must not carry the field at all.
        json|error streamOptions = payload.stream_options;
        test:assertTrue(streamOptions is error,
                "stream_options is deprecated on OpenRouter and must not be sent");
        return sseEvents([
            chatChunk(string `{"role":"assistant","content":"Hello"}`),
            // `system_fingerprint` is explicitly null on some upstream providers; the chunk
            // must still bind rather than being rejected as an unexpected shape.
            string `{"id":"gen-1","object":"chat.completion.chunk","created":1,` +
                string `"model":"openai/gpt-5","system_fingerprint":null,"choices":` +
                string `[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}`,
            chatChunkWithFinishReason("stop"),
            string `{"id":"gen-1","object":"chat.completion.chunk","created":1,` +
                string `"model":"openai/gpt-5","choices":[],` +
                string `"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}`,
            "[DONE]"
        ]);
    }

    // Frames carrying only `choices` - no `id`, `object`, `created`, `model` or
    // `system_fingerprint`. OpenRouter fronts many upstream providers, so a leaner envelope
    // than OpenAI's must still stream rather than being dropped.
    resource function post minimal/chat/completions() returns stream<http:SseEvent, error?>|error {
        return sseEvents([
            string `{"choices":[{"index":0,"delta":{"role":"assistant","content":"Lean"}}]}`,
            string `{"choices":[{"index":0,"delta":{"content":" envelope"},"finish_reason":"stop"}]}`,
            "[DONE]"
        ]);
    }

    // Two tool calls streamed in fragments, ending with a `tool_calls` finish reason.
    resource function post tools/chat/completions() returns stream<http:SseEvent, error?>|error {
        return sseEvents([
            chatChunk(string `{"role":"assistant","tool_calls":[{"index":0,"id":"call_a",` +
                    string `"type":"function","function":{"name":"getWeather","arguments":""}}]}`),
            chatChunk(string `{"tool_calls":[{"index":0,"function":{"arguments":"{\"city\":"}}]}`),
            chatChunk(string `{"tool_calls":[{"index":1,"id":"call_b","type":"function",` +
                    string `"function":{"name":"getTime","arguments":"{}"}}]}`),
            chatChunk(string `{"tool_calls":[{"index":0,"function":{"arguments":"\"Colombo\"}"}}]}`),
            chatChunkWithFinishReason("tool_calls"),
            "[DONE]"
        ]);
    }

    // Reasoning models routed through OpenRouter stream chain-of-thought as `reasoning`.
    resource function post reasoning/chat/completions() returns stream<http:SseEvent, error?>|error {
        return sseEvents([
            chatChunk(string `{"role":"assistant","reasoning":"Let me think"}`),
            chatChunk(string `{"reasoning":" about it"}`),
            chatChunk(string `{"content":"42"}`),
            chatChunkWithFinishReason("stop"),
            "[DONE]"
        ]);
    }

    // OpenRouter normalizes upstream failures to a finish reason of "error", which is
    // outside the `ai:FinishReason` set and must map to `()` rather than panicking.
    resource function post unknownfinish/chat/completions() returns stream<http:SseEvent, error?>|error {
        return sseEvents([
            chatChunk(string `{"role":"assistant","content":"Partial"}`),
            chatChunkWithFinishReason("error"),
            "[DONE]"
        ]);
    }

    // A generation cut short part-way: content, then the error frame OpenRouter emits in
    // place of the rest of the answer.
    resource function post midstreamerror/chat/completions() returns stream<http:SseEvent, error?>|error {
        return sseEvents([
            chatChunk(string `{"role":"assistant","content":"Partial"}`),
            string `{"error":{"code":429,"message":"Rate limit exceeded"}}`
        ]);
    }

    // A frame that is not JSON at all.
    resource function post malformed/chat/completions() returns stream<http:SseEvent, error?>|error {
        return sseEvents([
            chatChunk(string `{"role":"assistant","content":"Partial"}`),
            "{not json at all"
        ]);
    }

    // Keep-alive comments and blank frames, which carry no `data` and must be skipped
    // without ending the stream. OpenRouter sends `: OPENROUTER PROCESSING` while an
    // upstream provider is still warming up.
    resource function post keepalive/chat/completions() returns stream<http:SseEvent, error?>|error {
        return sseEvents([
            "",
            chatChunk(string `{"role":"assistant","content":"After"}`),
            "   ",
            chatChunk(string `{"content":" keep-alive"}`),
            chatChunkWithFinishReason("stop"),
            "[DONE]"
        ]);
    }

    // Asserts the OpenRouter attribution headers survive the hand-off to the raw streaming
    // client, which does not go through the generated connector.
    resource function post attribution/chat/completions(@http:Header {name: "HTTP-Referer"} string? referer,
            @http:Header {name: "X-OpenRouter-Title"} string? title)
            returns stream<http:SseEvent, error?>|error {
        test:assertEquals(referer, "https://example.com", "HTTP-Referer must reach the streaming endpoint");
        test:assertEquals(title, "Example App", "X-OpenRouter-Title must reach the streaming endpoint");
        return sseEvents([chatChunkWithFinishReason("stop"), "[DONE]"]);
    }

    // A rejected request: the endpoint answers with a normal JSON error body, not a stream.
    resource function post unauthorized/chat/completions() returns http:Response {
        return errorResponse(http:STATUS_UNAUTHORIZED, "No auth credentials found");
    }

    // OpenRouter answers 402 when the account has run out of credit - the failure a caller is
    // most likely to hit in practice, and the one a bare "could not open the stream" hides.
    resource function post insufficientcredits/chat/completions() returns http:Response {
        return errorResponse(http:STATUS_PAYMENT_REQUIRED, "Insufficient credits");
    }

    // A non-2xx whose body is not the usual JSON error envelope at all.
    resource function post plaintexterror/chat/completions() returns http:Response {
        http:Response response = new;
        response.statusCode = http:STATUS_BAD_GATEWAY;
        response.setTextPayload("upstream provider unavailable");
        return response;
    }
}

# Wraps each payload as the `data` of one Server-Sent Event.
#
# + payloads - The `data` payloads to emit, in order
# + return - The event stream the mock endpoint answers with
isolated function sseEvents(string[] payloads) returns stream<http:SseEvent, error?> {
    http:SseEvent[] events = from string payload in payloads
        select {data: payload};
    return events.toStream();
}

# Builds one `chat.completion.chunk` frame around the given delta.
#
# + delta - The `delta` object as a JSON string
# + return - The frame's `data` payload
isolated function chatChunk(string delta) returns string =>
    string `{"id":"gen-1","object":"chat.completion.chunk","created":1,"model":"openai/gpt-5",` +
        string `"system_fingerprint":"fp_test","choices":[{"index":0,"delta":${delta},"finish_reason":null}]}`;

# Builds the terminal `chat.completion.chunk` frame carrying a finish reason.
#
# + finishReason - The wire finish reason
# + return - The frame's `data` payload
isolated function chatChunkWithFinishReason(string finishReason) returns string =>
    string `{"id":"gen-1","object":"chat.completion.chunk","created":1,"model":"openai/gpt-5",` +
        string `"system_fingerprint":"fp_test","choices":[{"index":0,"delta":{},"finish_reason":"${finishReason}"}]}`;

# The JSON error body OpenRouter answers a rejected request with.
#
# + statusCode - The HTTP status to answer with
# + message - The failure detail carried in the error envelope
# + return - The error response
isolated function errorResponse(int statusCode, string message) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setJsonPayload({'error: {code: statusCode, message}});
    return response;
}
