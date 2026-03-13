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
import ballerina/ai.observe;
import ballerinax/openrouter;

# EmbeddingProvider is a client class that provides an interface for generating
# vector embeddings via the OpenRouter unified API, which supports embedding models
# from OpenAI, Google, Mistral, and other providers.
public isolated distinct client class EmbeddingProvider {
    *ai:EmbeddingProvider;
    private final openrouter:Client openrouterClient;
    private final string modelType;
    private final openrouter:CreateEmbeddingsHeaders & readonly requestHeaders;

    # Initializes the OpenRouter embedding provider with the given configuration.
    #
    # + apiKey - The OpenRouter API key (obtain from https://openrouter.ai/keys)
    # + modelType - The embedding model to use (e.g., `openai/text-embedding-3-small`)
    # + serviceUrl - The base URL of the OpenRouter API endpoint
    # + siteUrl - Optional site URL sent as `HTTP-Referer` header for OpenRouter attribution
    # + siteName - Optional site name sent as `X-OpenRouter-Title` header for OpenRouter attribution
    # + connectionConfig - Additional HTTP connection configuration
    # + return - `()` on successful initialization; otherwise, returns an `ai:Error`
    public isolated function init(@display {label: "API Key"} string apiKey,
            @display {label: "Model Type"} string modelType,
            @display {label: "Service URL"} string serviceUrl = DEFAULT_OPENROUTER_SERVICE_URL,
            @display {label: "Site URL"} string? siteUrl = (),
            @display {label: "Site Name"} string? siteName = (),
            @display {label: "Connection Configuration"} *ConnectionConfig connectionConfig) returns ai:Error? {
        openrouter:Client|ai:Error openrouterClient = buildOpenRouterClient(apiKey, serviceUrl, connectionConfig);
        if openrouterClient is ai:Error {
            return openrouterClient;
        }
        self.openrouterClient = openrouterClient;
        self.modelType = modelType;

        openrouter:CreateEmbeddingsHeaders headers = {};
        if siteUrl is string {
            headers["HTTP-Referer"] = siteUrl;
        }
        if siteName is string {
            headers["X-OpenRouter-Title"] = siteName;
        }
        self.requestHeaders = headers.cloneReadOnly();
    }

    # Converts the given chunk into a vector embedding.
    #
    # + chunk - The chunk to convert into an embedding (only `ai:TextChunk` and `ai:TextDocument` are supported)
    # + return - The embedding vector representation on success; `ai:LlmConnectionError` if the HTTP call
    #            fails; `ai:LlmInvalidResponseError` if the model returns no embeddings;
    #            `ai:Error` if the chunk type is not supported
    isolated remote function embed(ai:Chunk chunk) returns ai:Embedding|ai:Error {
        observe:EmbeddingSpan span = observe:createEmbeddingSpan(self.modelType);
        span.addProvider("openrouter");

        if chunk !is ai:TextChunk|ai:TextDocument {
            ai:Error err = error ai:Error(
                "Unsupported chunk type. Only 'ai:TextChunk|ai:TextDocument' is supported.");
            span.close(err);
            return err;
        }

        string content = chunk.content;
        span.addInputContent(content);

        openrouter:CreateEmbeddingsRequest request = {input: content, model: self.modelType};
        openrouter:CreateEmbeddingsResponse|error response = self.openrouterClient->/embeddings.post(
            request, self.requestHeaders);
        if response is error {
            ai:Error err = error ai:LlmConnectionError("Error while connecting to the embedding model", response);
            span.close(err);
            return err;
        }

        span.addResponseModel(response.model);
        decimal? inputTokens = response?.usage?.prompt_tokens;
        if inputTokens is decimal {
            span.addInputTokenCount(<int>inputTokens);
        }

        var data = response.data;
        if data.length() != 1 {
            ai:Error err = error ai:LlmInvalidResponseError(
                "Invalid embedding response: expected exactly one embedding with index 0");
            span.close(err);
            return err;
        }

        decimal[]|string embeddingRaw = data[0].embedding;
        if embeddingRaw !is decimal[] {
            ai:Error err = error ai:LlmInvalidResponseError(
                "Unsupported embedding format: base64 encoding is not supported, use float encoding.");
            span.close(err);
            return err;
        }

        span.close();
        return decimalToFloatArray(embeddingRaw);
    }

    # Converts a batch of chunks into vector embeddings.
    #
    # + chunks - The chunks to convert into embeddings (only `ai:TextChunk` and `ai:TextDocument` are supported)
    # + return - An array of embedding vectors on success; `ai:LlmConnectionError` if the HTTP call
    #            fails; `ai:LlmInvalidResponseError` if the model returns no embeddings;
    #            `ai:Error` if a chunk type is not supported
    isolated remote function batchEmbed(ai:Chunk[] chunks) returns ai:Embedding[]|ai:Error {
        if chunks.length() == 0 {
            return [];
        }
        observe:EmbeddingSpan span = observe:createEmbeddingSpan(self.modelType);
        span.addProvider("openrouter");

        if !isAllSupportedChunks(chunks) {
            ai:Error err = error ai:Error(
                "Unsupported chunk type. Expected elements of type 'ai:TextChunk|ai:TextDocument'.");
            span.close(err);
            return err;
        }

        string[] input = chunks.map(chunk => <string>chunk.content);
        span.addInputContent(input);

        openrouter:CreateEmbeddingsRequest request = {input, model: self.modelType};
        openrouter:CreateEmbeddingsResponse|error response = self.openrouterClient->/embeddings.post(
            request, self.requestHeaders);
        if response is error {
            ai:Error err = error ai:LlmConnectionError("Error while connecting to the embedding model", response);
            span.close(err);
            return err;
        }

        span.addResponseModel(response.model);
        decimal? inputTokens = response?.usage?.prompt_tokens;
        if inputTokens is decimal {
            span.addInputTokenCount(<int>inputTokens);
        }

        var data = response.data;
        if data.length() == 0 {
            ai:Error err = error ai:LlmInvalidResponseError("No embeddings returned from the model");
            span.close(err);
            return err;
        }
        if data.length() != chunks.length() {
            ai:Error err = error ai:LlmInvalidResponseError(
                string `Invalid embedding response: expected ${chunks.length()} embeddings but received ${data.length()}`);
            span.close(err);
            return err;
        }

        // Build an index-keyed map then collect in order (avoids sorting on decimal?)
        map<ai:Embedding> indexedEmbeddings = {};
        foreach var item in data {
            decimal? idx = item.index;
            if idx is () {
                ai:Error err = error ai:LlmInvalidResponseError(
                    "Invalid embedding response: item is missing an index");
                span.close(err);
                return err;
            }
            decimal[]|string embeddingRaw = item.embedding;
            if embeddingRaw !is decimal[] {
                ai:Error err = error ai:LlmInvalidResponseError(
                    "Unsupported embedding format: base64 encoding is not supported, use float encoding.");
                span.close(err);
                return err;
            }
            indexedEmbeddings[(<int>idx).toString()] = decimalToFloatArray(embeddingRaw);
        }
        ai:Embedding[] embeddings = [];
        foreach int i in 0 ..< data.length() {
            ai:Embedding? emb = indexedEmbeddings[i.toString()];
            if emb is () {
                ai:Error err = error ai:LlmInvalidResponseError(
                    "Invalid embedding response: indices do not form a complete 0..n-1 sequence");
                span.close(err);
                return err;
            }
            embeddings.push(emb);
        }

        span.close();
        return embeddings;
    }
}

// Returns true only when every element is either ai:TextChunk or ai:TextDocument.
isolated function isAllSupportedChunks(ai:Chunk[] chunks) returns boolean {
    return chunks.every(chunk => chunk is ai:TextChunk|ai:TextDocument);
}

// Converts a decimal[] returned by the connector to float[] required by ai:Embedding.
isolated function decimalToFloatArray(decimal[] values) returns float[] =>
    values.map(v => <float>v);
