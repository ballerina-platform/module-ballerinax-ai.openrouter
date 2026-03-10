// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
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


# Embedding model names available through the OpenRouter unified API.
# These models convert text into vector representations for semantic search and RAG workflows.
@display {label: "OpenRouter Embedding Model Names"}
public enum OPENROUTER_EMBEDDING_MODEL_NAMES {
    // ── OpenAI ──────────────────────────────────────────────────────────────
    # OpenAI text-embedding-3-small — fast, efficient, and low-cost
    OPENAI_TEXT_EMBEDDING_3_SMALL = "openai/text-embedding-3-small",
    # OpenAI text-embedding-3-large — highest accuracy for OpenAI embeddings
    OPENAI_TEXT_EMBEDDING_3_LARGE = "openai/text-embedding-3-large",
    # OpenAI text-embedding-ada-002 — legacy embedding model
    OPENAI_TEXT_EMBEDDING_ADA_002 = "openai/text-embedding-ada-002",
    // ── Google ──────────────────────────────────────────────────────────────
    # Google text-embedding-004 — Google's text embedding model
    GOOGLE_TEXT_EMBEDDING_004 = "google/text-embedding-004",
    // ── Mistral ─────────────────────────────────────────────────────────────
    # Mistral Embed — Mistral's embedding model
    MISTRAL_EMBED = "mistralai/mistral-embed"
}

// Internal types for OpenRouter embeddings API (/embeddings endpoint).

type EmbeddingRequest record {|
    string|string[] input;
    string model;
    string encoding_format = "float";
|};

// Open records so unknown OpenRouter fields are tolerated.
type EmbeddingDataItem record {
    float[] embedding;
    int index;
};

type EmbeddingUsage record {
    int prompt_tokens?;
    int total_tokens?;
};

type EmbeddingResponse record {
    string 'object;
    EmbeddingDataItem[] data;
    string model;
    EmbeddingUsage usage?;
};

type ToolInfo readonly & record {|
    string toolList;
    string toolIntro;
|};

type LlmChatResponse record {|
    string content;
|};

// Minimal OpenRouter chat completion types (OpenAI-compatible subset).
// Defined here to avoid depending on ballerinax/openai.chat.

type ChatFunctionCall record {|
    string name;
    string arguments;
|};

type ChatToolCallFunction record {|
    string name;
    string arguments;
|};

type ChatToolCall record {
    string id;
    string 'type;
    ChatToolCallFunction 'function;
};

// Open record so ai:ChatFunctionMessage / ai:ChatAssistantMessage values
// are structurally compatible when pushed directly into the message list.
type ChatRequestMessage record {
    string role;
    string? content?;
    string name?; // non-nullable optional — absent from JSON when not set
    ChatFunctionCall? function_call?;
};

type ChatCompletionRequest record {|
    ChatRequestMessage[] messages;
    string model;
    int? max_completion_tokens?;
    decimal? temperature?;
    string|string[]? stop?;
    ai:ChatCompletionFunctions[]? functions?;
|};

// Open records for responses so unknown OpenRouter fields are tolerated.
type ChatUsage record {
    int? prompt_tokens?;
    int? completion_tokens?;
};

type ChatResponseMessage record {
    string? content?;
    ChatFunctionCall? function_call?;
    ChatToolCall[]? tool_calls?;
};

type ChatCompletionChoice record {
    string? finish_reason?;
    ChatResponseMessage message;
};

type ChatCompletionResponse record {
    string id;
    ChatCompletionChoice[] choices;
    ChatUsage? usage?;
};
