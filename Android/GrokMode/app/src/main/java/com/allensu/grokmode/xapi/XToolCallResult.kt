package com.allensu.grokmode.xapi

import org.json.JSONObject

/**
 * Error details for a failed tool call.
 */
class XToolCallError(
    val code: String,
    override val message: String,
    val details: Map<String, String>? = null
) : Exception(message) {

    fun toJson(): JSONObject = JSONObject().apply {
        put("code", code)
        put("message", message)
        details?.let {
            put("details", JSONObject(it))
        }
    }

    companion object {
        fun authRequired() = XToolCallError(
            code = "AUTH_REQUIRED",
            message = "This action requires user authentication. Please log in to your X/Twitter account."
        )

        fun missingParam(paramName: String) = XToolCallError(
            code = "MISSING_PARAM",
            message = "Missing required parameter: $paramName"
        )

        fun unauthorized(message: String) = XToolCallError(
            code = "UNAUTHORIZED",
            message = "You don't have permission to perform this action: $message"
        )

        fun httpError(statusCode: Int, message: String) = XToolCallError(
            code = "HTTP_$statusCode",
            message = message
        )

        fun invalidResponse() = XToolCallError(
            code = "INVALID_RESPONSE",
            message = "Response is not HTTP"
        )

        fun requestFailed(message: String) = XToolCallError(
            code = "REQUEST_FAILED",
            message = message
        )

        fun invalidUrl(path: String) = XToolCallError(
            code = "INVALID_URL",
            message = "Failed to construct URL for path: $path"
        )

        fun notSupported(toolName: String) = XToolCallError(
            code = "NOT_SUPPORTED",
            message = "Tool $toolName is not expected to be handled by orchestrator"
        )
    }
}

/**
 * Result of executing a tool call.
 */
data class XToolCallResult(
    val id: String?,
    val toolName: String,
    val success: Boolean,
    val response: String?,   // JSON string - ready for LLM
    val error: XToolCallError?,
    val statusCode: Int?
) {
    /**
     * Convert to JSON for sending back to voice service.
     */
    fun toJson(): JSONObject = JSONObject().apply {
        id?.let { put("id", it) }
        put("tool_name", toolName)
        put("success", success)
        response?.let { put("response", it) }
        error?.let { put("error", it.toJson()) }
        statusCode?.let { put("status_code", it) }
    }

    /**
     * Get the output string for voice service tool output.
     * Returns either the response or error message.
     */
    fun getOutputForVoice(): String {
        return if (success) {
            response ?: "{}"
        } else {
            error?.toJson()?.toString() ?: """{"error": "Unknown error"}"""
        }
    }

    companion object {
        fun success(
            id: String? = null,
            toolName: String,
            response: String?,
            statusCode: Int
        ) = XToolCallResult(
            id = id,
            toolName = toolName,
            success = true,
            response = response,
            error = null,
            statusCode = statusCode
        )

        fun failure(
            id: String? = null,
            toolName: String,
            error: XToolCallError,
            statusCode: Int? = null
        ) = XToolCallResult(
            id = id,
            toolName = toolName,
            success = false,
            response = null,
            error = error,
            statusCode = statusCode
        )
    }
}
