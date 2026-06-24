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
import ballerina/http;

# Configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
@display {label: "Connection Configuration"}
public type ConnectionConfig record {|

    # The HTTP version understood by the client
    @display {label: "HTTP Version"}
    http:HttpVersion httpVersion = http:HTTP_2_0;

    # Configurations related to HTTP/1.x protocol
    @display {label: "HTTP1 Settings"}
    http:ClientHttp1Settings http1Settings?;

    # Configurations related to HTTP/2 protocol
    @display {label: "HTTP2 Settings"}
    http:ClientHttp2Settings http2Settings?;

    # The maximum time to wait (in seconds) for a response before closing the connection
    @display {label: "Timeout"}
    decimal timeout = 60;

    # The choice of setting `forwarded`/`x-forwarded` header
    @display {label: "Forwarded"}
    string forwarded = "disable";

    # Configurations associated with request pooling
    @display {label: "Pool Configuration"}
    http:PoolConfiguration poolConfig?;

    # HTTP caching related configurations
    @display {label: "Cache Configuration"}
    http:CacheConfig cache?;

    # Specifies the way of handling compression (`accept-encoding`) header
    @display {label: "Compression"}
    http:Compression compression = http:COMPRESSION_AUTO;

    # Configurations associated with the behaviour of the Circuit Breaker
    @display {label: "Circuit Breaker Configuration"}
    http:CircuitBreakerConfig circuitBreaker?;

    # Configurations associated with retrying
    @display {label: "Retry Configuration"}
    http:RetryConfig retryConfig?;

    # Configurations associated with inbound response size limits
    @display {label: "Response Limit Configuration"}
    http:ResponseLimitConfigs responseLimits?;

    # SSL/TLS-related options
    @display {label: "Secure Socket Configuration"}
    http:ClientSecureSocket secureSocket?;

    # Proxy server related options
    @display {label: "Proxy Configuration"}
    http:ProxyConfig proxy?;

    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    @display {label: "Payload Validation"}
    boolean validation = true;
|};

// ── Chat Completions streaming types ───────────────────────────────────────
// Models the streamed `chat.completion.chunk` objects emitted by the
// /chat/completions endpoint when `stream` is true. OpenRouter is
// OpenAI-compatible on the wire, with two notable differences handled here:
// the normalized `finish_reason` may carry values outside OpenAI's set (e.g.
// "error"), so it is typed as a `string?`; and reasoning models stream chain-
// of-thought via `delta.reasoning`.
// Reference: https://openrouter.ai/docs/api-reference/streaming

# A streamed chunk of a chat completion response, as part of a Server-Sent Events
# stream from the /chat/completions endpoint (object "chat.completion.chunk").
type CreateChatCompletionStreamResponse record {
    # Unique identifier for the chat completion; the same across every chunk
    string id;
    # Object type, always "chat.completion.chunk"
    string 'object;
    # Unix timestamp (seconds) of creation; the same across every chunk
    int created;
    # The model used to generate the completion
    string model;
    # A list of chat completion choices; can hold more than one when `n` > 1,
    # or be empty for the final usage-only chunk
    ChatCompletionStreamChoice[] choices;
    # Fingerprint of the backend configuration the model runs with
    string system_fingerprint?;
    # The service tier used for processing the request
    string? service_tier = ();
    # Token usage statistics. Null on every chunk except the final one, and only
    # present when `stream_options: { include_usage: true }` was set
    CompletionUsage? usage = ();
};

# A single choice within a streamed chat completion chunk
type ChatCompletionStreamChoice record {
    # Index of the choice in the list of choices
    int index;
    # The incremental delta of the chat message for this chunk
    ChatCompletionStreamResponseDelta delta;
    # Log-probability information for the choice, null when not requested
    ChatCompletionStreamChoiceLogprobs? logprobs = ();
    # Reason the model stopped generating tokens; null until the final chunk.
    # OpenRouter normalizes to stop/length/tool_calls/content_filter/error, so
    # this is kept as a `string?` and mapped safely by `mapFinishReason`.
    string? finish_reason = ();
};

# A chat completion delta generated by streamed model responses
type ChatCompletionStreamResponseDelta record {
    # Role of the author of this message; only sent on the first delta
    string role?;
    # The contents of the chunk message, null for non-content deltas
    string? content = ();
    # The reasoning (chain-of-thought) content streamed by reasoning models,
    # null for non-reasoning deltas
    string? reasoning = ();
    # The refusal message generated by the model, null when not refusing
    string? refusal = ();
    # Incremental tool calls generated by the model
    ChatCompletionMessageToolCallChunk[] tool_calls?;
    # Deprecated and replaced by `tool_calls`; the name and arguments of the
    # function to call
    record {
        # The name of the function to call
        string name?;
        # The arguments to call the function with, as a JSON string
        string arguments?;
    } function_call?;
};

# An incremental tool call delivered within a streamed delta. With parallel tool
# calling enabled, several tool calls stream concurrently, distinguished by `index`.
type ChatCompletionMessageToolCallChunk record {
    # Index of the tool call in the message's `tool_calls` array; used to
    # correlate fragments of the same tool call across chunks
    int index;
    # Identifier of the tool call; only sent on the first chunk of the call
    string id?;
    # The type of the tool, always "function"; only sent on the first chunk
    string 'type?;
    # The function the model is calling
    ChatCompletionMessageToolCallChunkFunction 'function?;
};

# The function fragment of a streamed tool call chunk
type ChatCompletionMessageToolCallChunkFunction record {
    # Name of the function to call; only sent on the first chunk of the call
    string name?;
    # Incremental fragment of the function arguments, accumulated as a JSON string
    string arguments?;
};

# Log-probability information for a streamed choice
type ChatCompletionStreamChoiceLogprobs record {
    # Log probabilities of the content tokens, null when none
    ChatCompletionTokenLogprob[]? content = ();
    # Log probabilities of the refusal tokens, null when none
    ChatCompletionTokenLogprob[]? refusal = ();
};

# Log-probability information for a single token
type ChatCompletionTokenLogprob record {
    # The token
    string token;
    # The log probability of this token
    decimal logprob;
    # UTF-8 byte representation of the token, null when unavailable
    int[]? bytes = ();
    # The most likely tokens and their log probabilities at this position
    ChatCompletionTokenTopLogprob[] top_logprobs;
};

# A candidate token and its log probability at a given position
type ChatCompletionTokenTopLogprob record {
    # The token
    string token;
    # The log probability of this token
    decimal logprob;
    # UTF-8 byte representation of the token, null when unavailable
    int[]? bytes = ();
};

# Usage statistics for the completion request, sent on the final chunk when
# `stream_options: { include_usage: true }` is set
type CompletionUsage record {
    # Number of tokens in the prompt
    int prompt_tokens;
    # Number of tokens in the generated completion
    int completion_tokens;
    # Total tokens used (prompt + completion)
    int total_tokens;
    # Breakdown of tokens used in the completion
    CompletionTokensDetails completion_tokens_details?;
    # Breakdown of tokens used in the prompt
    PromptTokensDetails prompt_tokens_details?;
};

# Breakdown of tokens used in a completion
type CompletionTokensDetails record {
    # Tokens generated for reasoning (reasoning models)
    int reasoning_tokens?;
    # Audio input tokens generated by the model
    int audio_tokens?;
    # Tokens generated by accepted prediction outputs
    int accepted_prediction_tokens?;
    # Tokens generated by rejected prediction outputs
    int rejected_prediction_tokens?;
};

# Breakdown of tokens present in the prompt
type PromptTokensDetails record {
    # Audio input tokens present in the prompt
    int audio_tokens?;
    # Prompt tokens served from cache
    int cached_tokens?;
};

// ── Wire → normalized mapping ──────────────────────────────────────────────
// Projects an OpenRouter `chat.completion.chunk` (the wire types above) onto the
// normalized `ai:ChatCompletionChunk` that `chatStream` must return. Only the
// subset the `ai` type can hold is mapped; everything else is ignored.

# Maps an OpenRouter wire chunk onto the normalized `ai:ChatCompletionChunk`.
# Forwards tool calls on every chunk (not just the first), so argument fragments
# stream through correctly.
#
# + w - The parsed OpenRouter wire chunk
# + return - The normalized chunk consumed by the `ai` module
isolated function toAiChunk(CreateChatCompletionStreamResponse w) returns ai:ChatCompletionChunk {
    ai:ChatCompletionChunkChoice[] choices = [];
    foreach ChatCompletionStreamChoice c in w.choices {
        ai:ChatCompletionChunkDelta delta = {content: c.delta.content};
        ai:ROLE? role = mapRole(c.delta?.role);
        if role is ai:ROLE {
            delta.role = role;
        }
        string? reasoning = c.delta?.reasoning;
        if reasoning is string {
            delta.reasoning = reasoning;
        }
        ChatCompletionMessageToolCallChunk[]? wireToolCalls = c.delta?.tool_calls;
        if wireToolCalls is ChatCompletionMessageToolCallChunk[] {
            ai:ToolCallChunk[] toolCalls = [];
            foreach ChatCompletionMessageToolCallChunk t in wireToolCalls {
                ai:ToolCallChunk toolCall = {index: t.index};
                string? id = t?.id;
                if id is string {
                    toolCall.id = id;
                }
                ChatCompletionMessageToolCallChunkFunction? fn = t?.'function;
                if fn is ChatCompletionMessageToolCallChunkFunction {
                    ai:FunctionCallChunk functionFragment = {};
                    string? name = fn?.name;
                    if name is string {
                        functionFragment.name = name;
                    }
                    string? arguments = fn?.arguments;
                    if arguments is string {
                        functionFragment.arguments = arguments;
                    }
                    toolCall.'function = functionFragment;
                }
                toolCalls.push(toolCall);
            }
            delta.toolCalls = toolCalls;
        }
        choices.push({index: c.index, delta, finishReason: mapFinishReason(c.finish_reason)});
    }

    ai:ChatCompletionChunk chunk = {id: w.id, model: w.model, choices};
    CompletionUsage? usage = w.usage;
    if usage is CompletionUsage {
        chunk.usage = {
            promptTokens: usage.prompt_tokens,
            completionTokens: usage.completion_tokens,
            totalTokens: usage.total_tokens
        };
    }
    return chunk;
}

# Safely maps an OpenRouter role string onto the `ai:ROLE` enum; returns `()` for
# absent or unrecognized values rather than panicking on a cast.
#
# + role - The role string from the wire delta
# + return - The mapped `ai:ROLE`, or `()` when absent/unrecognized
isolated function mapRole(string? role) returns ai:ROLE? {
    // Streamed response deltas only carry the "assistant" role; "system"/"user"
    // are handled for completeness. ("function" is request-only and the `ai`
    // enum member is not accessible here, so it is intentionally omitted.)
    match role {
        "system" => {
            return ai:SYSTEM;
        }
        "user" => {
            return ai:USER;
        }
        "assistant" => {
            return ai:ASSISTANT;
        }
    }
    return ();
}

# Safely maps an OpenRouter finish reason onto the `ai:FinishReason` enum. The
# `ai` enum has no `function_call` member, so the deprecated `function_call`
# value is folded into `tool_calls`. Returns `()` for absent or unrecognized
# values (e.g. OpenRouter's `error`).
#
# + finishReason - The finish reason from the wire chunk
# + return - The mapped `ai:FinishReason`, or `()` when absent/unrecognized
isolated function mapFinishReason(string? finishReason) returns ai:FinishReason? {
    match finishReason {
        "stop" => {
            return ai:STOP;
        }
        "length" => {
            return ai:LENGTH;
        }
        "tool_calls"|"function_call" => {
            return ai:TOOL_CALLS;
        }
        "content_filter" => {
            return ai:CONTENT_FILTER;
        }
    }
    return ();
}
