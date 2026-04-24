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

isolated function getExpectedParameterSchema(string message) returns map<json> {
    if message.startsWith("Evaluate this") {
        return expectedParameterSchemaStringForRateBlog6;
    }

    if message.startsWith("Rate this blog") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("Please rate this blogs") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("Please rate this blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("What is") {
        return expectedParameterSchemaStringForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedParameterSchemaStringForRateBlog4;
    }

    if message.startsWith("How would you rate these text chunks") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("How would you rate this text chunk") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("How would you rate these text blogs") {
        return expectedParameterSchemaStringForRateBlog5;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedParameterSchemaStringForRateBlog2;
    }

    if message.startsWith("How would you rate this") {
        return expectedParameterSchemaStringForRateBlog;
    }

    if message.startsWith("Which country") {
        return expectedParamterSchemaStringForCountry;
    }

    if message.startsWith("Describe the following 2 images") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("Please describe the following image and the doc") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("Describe the following text document and image document") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("What is the content in this document") {
        return expectedParameterSchemaStringForRateBlog7;
    }

    if message.startsWith("Describe the following image") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("Describe the image") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("Please describe the image") {
        return expectedParameterSchemaStringForRateBlog8;
    }

    if message.startsWith("Give me a random joke") {
        return {"type": "object", "properties": {"result": {"anyOf": [{"type": "string"}, {"type": "null"}]}}};
    }

    return {};
}

isolated function getTheMockLLMResult(string message) returns string {
    if message.startsWith("Evaluate this") {
        return string `{"result": [9, 1]}`;
    }

    if message.startsWith("Rate this blog") {
        return "{\"result\": 4}";
    }

    if message.startsWith("Please rate this blogs") {
        return string `{"result": [${review}, ${review}]}`;
    }

    if message.startsWith("Please rate this blog") {
        return review;
    }

    if message.startsWith("What is") {
        return "{\"result\": 2}";
    }

    if message.startsWith("Tell me") {
        return "{\"result\": [{\"name\": \"Virat Kohli\", \"age\": 33}, {\"name\": \"Kane Williamson\", \"age\": 30}]}";
    }

    if message.startsWith("Which country") {
        return "{\"result\": \"Sri Lanka\"}";
    }

    if message.startsWith("How would you rate these text chunks") {
        return string `{"result": [${review}, ${review}]}`;
    }

    if message.startsWith("How would you rate this text chunk") {
        return "{\"result\": 4}";
    }

    if message.startsWith("How would you rate these text blogs") {
        return string `{"result": [${review}, ${review}]}`;
    }

    if message.startsWith("How would you rate this text blog") {
        return review;
    }

    if message.startsWith("How would you rate this") {
        return "{\"result\": 4}";
    }

    if message.startsWith("Describe the following 2 images") {
        return "{\"result\": [\"This is a sample image description.\", \"This is a sample image description.\"]}";
    }

    if message.startsWith("Please describe the following image and the doc") {
        return "{\"result\": [\"This is a sample image description.\", \"This is a sample doc description.\"]}";
    }

    if message.startsWith("Describe the following text document and image document") {
        return "{\"result\": [\"This is a sample image description.\", \"This is a sample doc description.\"]}";
    }

    if message.startsWith("What is the content in this document") {
        return "{\"result\": [\"This is a sample image description.\"]}";
    }

    if message.startsWith("Describe the following image") {
        return "{\"result\": \"This is a sample image description.\"}";
    }

    if message.startsWith("Describe the image") {
        return "{\"result\": \"This is a sample image description.\"}";
    }

    if message.startsWith("Please describe the image") {
        return "{\"result\": \"This is a sample image description.\"}";
    }

    if message.startsWith("Give me a random joke") {
        return "{\"result\": \"This is a random joke\"}";
    }

    return "INVALID";
}

isolated function getTestServiceResponse(string content) returns json => {
    "id": "test-id",
    "object": "chat.completion",
    "created": 1234567890,
    "model": "openai/gpt-4o",
    "choices": [
        {
            "finish_reason": "tool_calls",
            "index": 0,
            "message": {
                "role": "assistant",
                "tool_calls": [
                    {
                        "id": "tool-call-id",
                        "type": "function",
                        "function": {
                            "name": GET_RESULTS_TOOL,
                            "arguments": getTheMockLLMResult(content)
                        }
                    }
                ]
            }
        }
    ]
};

isolated function getExpectedContentParts(string message) returns map<anydata>[] {
    if message.startsWith("Rate this blog") {
        return expectedContentPartsForRateBlog;
    }

    if message.startsWith("Evaluate this") {
        return expectedContentPartsForRateBlog10;
    }

    if message.startsWith("Please rate this blogs") {
        return expectedContentPartsForRateBlog7;
    }

    if message.startsWith("Please rate this blog") {
        return expectedContentPartsForRateBlog2;
    }

    if message.startsWith("What is") {
        return expectedContentPartsForRateBlog3;
    }

    if message.startsWith("Tell me") {
        return expectedContentPartsForRateBlog4;
    }

    if message.startsWith("How would you rate these text chunks") {
        return expectedContentPartsForTextChunkArray;
    }

    if message.startsWith("How would you rate this text chunk") {
        return expectedContentPartsForTextChunk;
    }

    if message.startsWith("How would you rate these text blogs") {
        return expectedContentPartsForRateBlog9;
    }

    if message.startsWith("How would you rate this text blog") {
        return expectedContentPartsForRateBlog8;
    }

    if message.startsWith("How would you rate this") {
        return expectedContentPartsForRateBlog5;
    }

    if message.startsWith("Which country") {
        return expectedContentPartsForCountry;
    }

    if message.startsWith("Describe the following 2 images") {
        return [
            {"type": "text", "text": "Describe the following 2 images. "},
            {
                "type": "image_url",
                "image_url": {
                    "url": string `data:image/png;base64,${sampleBase64Str}`,
                    "detail": "auto"
                }
            },
            {
                "type": "image_url",
                "image_url": {
                    "url": sampleImageUrl,
                    "detail": "auto"
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Please describe the following image and the doc") {
        return [
            {"type": "text", "text": "Please describe the following image and the doc. "},
            {
                "type": "image_url",
                "image_url": {
                    "url": string `data:image/png;base64,${sampleBase64Str}`,
                    "detail": "auto"
                }
            },
            {
                "type": "text",
                "text": string `Title: ${blog1.title} Content: ${blog1.content}`
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Describe the following text document and image document") {
        return [
            {"type": "text", "text": "Describe the following text document and image document. "},
            {
                "type": "image_url",
                "image_url": {
                    "url": string `data:image/png;base64,${sampleBase64Str}`,
                    "detail": "auto"
                }
            },
            {
                "type": "text",
                "text": string `Title: ${blog1.title} Content: ${blog1.content}`
            }
        ];
    }

    if message.startsWith("Describe the following image") {
        return [
            {"type": "text", "text": "Describe the following image. "},
            {
                "type": "image_url",
                "image_url": {
                    "url": string `data:image/*;base64,${sampleBase64Str}`,
                    "detail": "auto"
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Describe the image") {
        return [
            {"type": "text", "text": "Describe the image. "},
            {
                "type": "image_url",
                "image_url": {
                    "url": sampleImageUrl,
                    "detail": "auto"
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Please describe the image") {
        return [
            {"type": "text", "text": "Please describe the image. "},
            {
                "type": "image_url",
                "image_url": {
                    "url": "This-is-not-a-valid-url",
                    "detail": "auto"
                }
            },
            {"type": "text", "text": "."}
        ];
    }

    if message.startsWith("Give me a random joke") {
        return [{"type": "text", "text": "Give me a random joke"}];
    }

    return [
        {
            "type": "text",
            "text": "INVALID"
        }
    ];
}
