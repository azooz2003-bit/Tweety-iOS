package com.allensu.grokmode.auth

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.allensu.grokmode.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.TimeUnit

sealed class AuthError(message: String) : Exception(message) {
    class MissingClientID : AuthError("Missing client ID")
    class InvalidURL : AuthError("Invalid URL")
    class LoginCancelled : AuthError("Login cancelled")
    class LoginFailed(message: String) : AuthError(message)
    class NetworkError(message: String) : AuthError(message)
}

data class AuthState(
    val isAuthenticated: Boolean,
    val currentUserHandle: String?
)

class XAuthService(context: Context) {

    private val callbackScheme = "grokmode"
    private val clientId = BuildConfig.X_CLIENT_ID
    private val baseProxyUrl = BuildConfig.BASE_X_PROXY_URL
    private val appSecret = BuildConfig.APP_SECRET

    // Token URLs via proxy
    private val tokenUrl = "${baseProxyUrl}oauth2/token"
    private val refreshUrl = "${baseProxyUrl}oauth2/refresh"

    // PKCE
    private var codeVerifier: String? = null

    // HTTP client
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    // Encrypted storage
    private val prefs: SharedPreferences

    // Storage keys
    private val tokenKey = "x_user_access_token"
    private val refreshTokenKey = "x_user_refresh_token"
    private val handleKey = "x_user_handle"
    private val tokenExpiryKey = "x_token_expiry_date"
    private val codeVerifierKey = "x_code_verifier"

    init {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        prefs = EncryptedSharedPreferences.create(
            context,
            "grokmode_secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun checkStatus(): AuthState {
        val token = prefs.getString(tokenKey, null)
        return if (!token.isNullOrEmpty()) {
            AuthState(
                isAuthenticated = true,
                currentUserHandle = prefs.getString(handleKey, null)
            )
        } else {
            AuthState(isAuthenticated = false, currentUserHandle = null)
        }
    }

    fun buildAuthUrl(): String {
        require(clientId.isNotEmpty()) { "X_CLIENT_ID not configured" }

        // Generate PKCE
        val verifier = generateCodeVerifier()
        // Save to both memory and storage (storage survives activity recreation)
        codeVerifier = verifier
        prefs.edit().putString(codeVerifierKey, verifier).apply()
        val challenge = generateCodeChallenge(verifier)

        val state = java.util.UUID.randomUUID().toString()

        return Uri.parse("https://twitter.com/i/oauth2/authorize").buildUpon()
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("client_id", clientId)
            .appendQueryParameter("redirect_uri", "$callbackScheme://")
            .appendQueryParameter("scope", "tweet.read tweet.write tweet.moderate.write users.read follows.read follows.write space.read mute.read mute.write like.read like.write list.read list.write block.read block.write bookmark.read bookmark.write media.write dm.read dm.write offline.access")
            .appendQueryParameter("state", state)
            .appendQueryParameter("code_challenge", challenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .build()
            .toString()
    }

    suspend fun handleCallback(uri: Uri): AuthState {
        val code = uri.getQueryParameter("code")
            ?: throw AuthError.LoginFailed("Missing authorization code")

        return exchangeCodeForToken(code)
    }

    private suspend fun exchangeCodeForToken(code: String): AuthState = withContext(Dispatchers.IO) {
        // Try memory first, then storage (in case activity was recreated)
        val verifier = codeVerifier ?: prefs.getString(codeVerifierKey, null)
            ?: throw AuthError.LoginFailed("Missing code verifier")

        val jsonBody = JSONObject().apply {
            put("code", code)
            put("redirect_uri", "$callbackScheme://")
            put("code_verifier", verifier)
        }

        val request = Request.Builder()
            .url(tokenUrl)
            .post(jsonBody.toString().toRequestBody("application/json".toMediaType()))
            .addHeader("Content-Type", "application/json")
            .addHeader("X-App-Secret", appSecret)
            .build()

        try {
            val response = httpClient.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""

            if (!response.isSuccessful) {
                throw AuthError.LoginFailed("Token exchange failed: $responseBody")
            }

            val json = JSONObject(responseBody)
            val accessToken = json.optString("access_token")
            if (accessToken.isEmpty()) {
                throw AuthError.LoginFailed("Invalid token response")
            }

            val refreshToken = json.optString("refresh_token", null)
            val expiresIn = json.optInt("expires_in", 7200)

            // Calculate expiry
            val expiryTime = System.currentTimeMillis() + (expiresIn * 1000L)

            // Save tokens
            prefs.edit().apply {
                putString(tokenKey, accessToken)
                putLong(tokenExpiryKey, expiryTime)
                refreshToken?.let { putString(refreshTokenKey, it) }
                apply()
            }

            // Clear verifier from memory and storage
            codeVerifier = null
            prefs.edit().remove(codeVerifierKey).apply()

            // Fetch user info (non-critical)
            fetchCurrentUser(accessToken)

            checkStatus()
        } catch (e: AuthError) {
            throw e
        } catch (e: Exception) {
            throw AuthError.NetworkError(e.message ?: "Unknown error")
        }
    }

    private suspend fun fetchCurrentUser(token: String) = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url("https://api.x.com/2/users/me")
                .addHeader("Authorization", "Bearer $token")
                .build()

            val response = httpClient.newCall(request).execute()
            val responseBody = response.body?.string() ?: return@withContext

            val json = JSONObject(responseBody)
            val data = json.optJSONObject("data") ?: return@withContext
            val username = data.optString("username")

            if (username.isNotEmpty()) {
                prefs.edit().putString(handleKey, "@$username").apply()
            }
        } catch (_: Exception) {
            // Silently fail - user info is non-critical
        }
    }

    fun logout() {
        codeVerifier = null
        prefs.edit().apply {
            remove(tokenKey)
            remove(refreshTokenKey)
            remove(handleKey)
            remove(tokenExpiryKey)
            remove(codeVerifierKey)
            apply()
        }
    }

    fun getAccessToken(): String? = prefs.getString(tokenKey, null)

    suspend fun getValidAccessToken(): String? {
        val token = prefs.getString(tokenKey, null)
        if (token.isNullOrEmpty()) return null

        if (isTokenExpired()) {
            return try {
                refreshAccessToken()
            } catch (_: Exception) {
                logout()
                null
            }
        }

        return token
    }

    private fun isTokenExpired(): Boolean {
        val expiryTime = prefs.getLong(tokenExpiryKey, 0L)
        if (expiryTime == 0L) return true

        // Consider expired if within 5 minutes
        val bufferTime = 5 * 60 * 1000L
        return System.currentTimeMillis() + bufferTime >= expiryTime
    }

    private suspend fun refreshAccessToken(): String = withContext(Dispatchers.IO) {
        val refreshToken = prefs.getString(refreshTokenKey, null)
            ?: throw AuthError.NetworkError("No refresh token available")

        val jsonBody = JSONObject().apply {
            put("refresh_token", refreshToken)
        }

        val request = Request.Builder()
            .url(refreshUrl)
            .post(jsonBody.toString().toRequestBody("application/json".toMediaType()))
            .addHeader("Content-Type", "application/json")
            .addHeader("X-App-Secret", appSecret)
            .build()

        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: ""

        if (!response.isSuccessful) {
            throw AuthError.NetworkError("Token refresh failed: $responseBody")
        }

        val json = JSONObject(responseBody)
        val accessToken = json.optString("access_token")
        if (accessToken.isEmpty()) {
            throw AuthError.NetworkError("Invalid refresh response")
        }

        val newRefreshToken = json.optString("refresh_token", null)
        val expiresIn = json.optInt("expires_in", 7200)
        val expiryTime = System.currentTimeMillis() + (expiresIn * 1000L)

        prefs.edit().apply {
            putString(tokenKey, accessToken)
            putLong(tokenExpiryKey, expiryTime)
            newRefreshToken?.let { putString(refreshTokenKey, it) }
            apply()
        }

        accessToken
    }

    // PKCE helpers
    private fun generateCodeVerifier(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
    }

    private fun generateCodeChallenge(verifier: String): String {
        val bytes = verifier.toByteArray(Charsets.US_ASCII)
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return Base64.encodeToString(digest, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
    }
}
