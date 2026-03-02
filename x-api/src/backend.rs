//! HTTP backend abstractions and implementations for X/Twitter API calls.

use base64::Engine;
use oauth_client::{ParamList, Token};
use reqwest::StatusCode;
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::borrow::Cow;
use std::collections::{HashMap, VecDeque};
use std::io::{BufRead, BufReader};

/// Extracts a human-readable error message from an API error response body.
///
/// Parses JSON error bodies using the same priority as the Ruby x gem:
/// 1. `errors` array — join each element's `message` field with ", "
/// 2. `title` + `detail` — format as "Title: Detail"
/// 3. `error` string field — use as-is
/// 4. Fallback — HTTP status reason phrase
pub fn format_api_error(status: StatusCode, body: &str) -> String {
    let parsed = if let Ok(json) = serde_json::from_str::<Value>(body) {
        // Priority 1: errors array with message fields
        if let Some(errors) = json.get("errors").and_then(Value::as_array) {
            let messages: Vec<&str> = errors
                .iter()
                .filter_map(|e| e.get("message").and_then(Value::as_str))
                .collect();
            if !messages.is_empty() {
                Some(messages.join(", "))
            } else {
                None
            }
        } else {
            None
        }
        // Priority 2: title + detail
        .or_else(|| {
            let title = json.get("title").and_then(Value::as_str)?;
            let detail = json.get("detail").and_then(Value::as_str)?;
            Some(format!("{title}: {detail}"))
        })
        // Priority 3: error string field
        .or_else(|| json.get("error").and_then(Value::as_str).map(String::from))
    } else {
        None
    };

    // Priority 4: fallback to status reason
    let message = parsed.unwrap_or_else(|| {
        status
            .canonical_reason()
            .unwrap_or("Unknown error")
            .to_string()
    });

    format!("{}: {message}", status.as_u16())
}

#[derive(Debug, Clone, PartialEq, Eq)]
/// A recorded backend invocation.
pub struct CallRecord {
    /// HTTP verb or logical method name (for example `GET`, `POST_JSON_OAUTH2`, `STREAM`).
    pub method: String,
    /// Request path used by the caller.
    pub path: String,
    /// Query/form parameters captured for the call.
    pub params: Vec<(String, String)>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
/// Authentication mode used for a request.
pub enum AuthScheme {
    /// OAuth 1.0a user-context signing with consumer and access tokens.
    OAuth1User,
    /// OAuth 2 bearer token authentication.
    OAuth2Bearer,
}

#[derive(Debug, thiserror::Error)]
/// Errors returned by backend operations.
pub enum BackendError {
    /// No active credentials were available in profile configuration.
    #[error("No active credentials found in profile")]
    MissingCredentials,
    /// Network, OAuth, or HTTP status failure.
    ///
    /// For API errors, the message is formatted as `"NNN: human-readable message"` where NNN
    /// is the HTTP status code. This allows callers to match on status codes while keeping
    /// a human-readable message for display.
    #[error("{0}")]
    Http(String),
    /// JSON parsing failure.
    #[error("JSON parse error: {0}")]
    Json(#[from] serde_json::Error),
    /// The mock backend had no queued response for the requested method/path pair.
    #[error("Mock backend has no response for {method} {path}")]
    MissingMockResponse {
        /// Requested method.
        method: String,
        /// Requested path.
        path: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
/// API credentials loaded from rc profile data.
pub struct Credentials {
    /// Account username or screen name.
    #[serde(default)]
    pub username: String,
    /// OAuth consumer key.
    #[serde(default)]
    pub consumer_key: String,
    /// OAuth consumer secret.
    #[serde(default)]
    pub consumer_secret: String,
    /// OAuth access token.
    #[serde(default)]
    pub token: String,
    /// OAuth access token secret.
    #[serde(default)]
    pub secret: String,
    /// Optional OAuth2 bearer token override.
    #[serde(default)]
    pub bearer_token: Option<String>,
}

/// Default number of attempts used by retry helper functions.
pub const DEFAULT_RETRY_TRIES: usize = 3;

/// Returns `true` if the error looks like a transient failure worth retrying
/// (5xx server errors or 429 rate-limit responses).
fn is_retryable(error: &BackendError) -> bool {
    let BackendError::Http(msg) = error else {
        return false;
    };
    // format_api_error prefixes with "NNN: " — check the leading digits
    let code: u16 = msg.get(..3).and_then(|s| s.parse().ok()).unwrap_or(0);
    (500..600).contains(&code) || code == 429
}

/// Runs an operation up to `tries` times, retrying only on transient errors
/// (5xx and 429). Client errors (4xx except 429) fail immediately to avoid
/// wasting API quota.
///
/// Values less than `1` are treated as a single attempt.
pub fn retry_with<T, F>(tries: usize, mut operation: F) -> Result<T, BackendError>
where
    F: FnMut() -> Result<T, BackendError>,
{
    let mut last_error = None;
    let attempts = tries.max(1);

    for _ in 0..attempts {
        match operation() {
            Ok(value) => return Ok(value),
            Err(error) if is_retryable(&error) => last_error = Some(error),
            Err(error) => return Err(error),
        }
    }

    Err(last_error.unwrap_or_else(|| BackendError::Http("request failed".to_string())))
}

/// Calls [`Backend::get_json`] with [`DEFAULT_RETRY_TRIES`] attempts.
pub fn get_json_with_retry(
    backend: &mut dyn Backend,
    path: &str,
    params: Vec<(String, String)>,
) -> Result<Value, BackendError> {
    retry_with(DEFAULT_RETRY_TRIES, || {
        backend.get_json(path, params.clone())
    })
}

/// Calls [`Backend::post_json`] with [`DEFAULT_RETRY_TRIES`] attempts.
pub fn post_json_with_retry(
    backend: &mut dyn Backend,
    path: &str,
    params: Vec<(String, String)>,
) -> Result<Value, BackendError> {
    retry_with(DEFAULT_RETRY_TRIES, || {
        backend.post_json(path, params.clone())
    })
}

/// Calls [`Backend::get_json_oauth2`] with [`DEFAULT_RETRY_TRIES`] attempts.
pub fn get_json_oauth2_with_retry(
    backend: &mut dyn Backend,
    path: &str,
    params: Vec<(String, String)>,
) -> Result<Value, BackendError> {
    retry_with(DEFAULT_RETRY_TRIES, || {
        backend.get_json_oauth2(path, params.clone())
    })
}

/// Calls [`Backend::post_json_body_oauth2`] with [`DEFAULT_RETRY_TRIES`] attempts.
pub fn post_json_body_oauth2_with_retry(
    backend: &mut dyn Backend,
    path: &str,
    body: Value,
) -> Result<Value, BackendError> {
    retry_with(DEFAULT_RETRY_TRIES, || {
        backend.post_json_body_oauth2(path, body.clone())
    })
}

/// Transport abstraction used by the `x` CLI command runner.
pub trait Backend {
    /// Executes an OAuth1 GET request and returns parsed JSON.
    fn get_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError>;

    /// Executes an OAuth1 POST request and returns parsed JSON.
    fn post_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError>;

    /// Executes an OAuth1 POST request with a JSON body and returns parsed JSON.
    fn post_json_body(&mut self, path: &str, body: Value) -> Result<Value, BackendError>;

    /// Executes an OAuth2 POST request with a JSON body and returns parsed JSON.
    fn post_json_body_oauth2(&mut self, path: &str, body: Value) -> Result<Value, BackendError>;

    /// Executes an OAuth1 DELETE request and returns parsed JSON.
    fn delete_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError>;

    /// Executes an OAuth2 GET request and returns parsed JSON.
    fn get_json_oauth2(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError>;

    /// Opens a streaming endpoint and emits each decoded JSON line to `on_event`.
    ///
    /// Returning `false` from `on_event` stops the stream.
    fn stream_json_lines(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
        auth: AuthScheme,
        on_event: &mut dyn FnMut(Value) -> bool,
    ) -> Result<(), BackendError>;

    /// Returns a log of calls made through this backend instance.
    fn calls(&self) -> &[CallRecord];
}

#[derive(Debug, Clone)]
/// Live backend implementation that talks to `https://api.twitter.com`.
pub struct TwitterBackend {
    base_url: String,
    credentials: Credentials,
    bearer_token: Option<String>,
    client: Client,
    calls: Vec<CallRecord>,
}

impl TwitterBackend {
    /// Creates a backend from profile credentials.
    ///
    /// Bearer token resolution order:
    ///
    /// 1. `X_BEARER_TOKEN`
    /// 2. `T_BEARER_TOKEN`
    /// 3. [`Credentials::bearer_token`]
    pub fn from_credentials(credentials: Credentials) -> Result<Self, BackendError> {
        let bearer_token = std::env::var("X_BEARER_TOKEN")
            .ok()
            .filter(|value| !value.trim().is_empty())
            .or_else(|| {
                std::env::var("T_BEARER_TOKEN")
                    .ok()
                    .filter(|value| !value.trim().is_empty())
            })
            .or_else(|| credentials.bearer_token.clone());

        let client = Client::builder()
            .user_agent("x-rust/5.0")
            .build()
            .map_err(|error| BackendError::Http(error.to_string()))?;

        Ok(Self {
            base_url: "https://api.twitter.com".to_string(),
            credentials,
            bearer_token,
            client,
            calls: Vec::new(),
        })
    }

    fn request_oauth1_signed(
        &mut self,
        method: &str,
        path: &str,
        params: Vec<(String, String)>,
        json_body: Option<Value>,
    ) -> Result<Value, BackendError> {
        let url = self.absolute_url(path);

        let mut other_param = ParamList::new();
        for (key, value) in &params {
            other_param.insert(Cow::Owned(key.clone()), Cow::Owned(value.clone()));
        }
        let other = if other_param.is_empty() {
            None
        } else {
            Some(&other_param)
        };

        let consumer = Token::new(
            self.credentials.consumer_key.as_str(),
            self.credentials.consumer_secret.as_str(),
        );
        let access = Token::new(
            self.credentials.token.as_str(),
            self.credentials.secret.as_str(),
        );
        let (auth_value, _body) =
            oauth_client::authorization_header(method, &url, &consumer, Some(&access), other);

        let query = if params.is_empty() {
            String::new()
        } else {
            serde_urlencoded::to_string(&params)
                .map_err(|error| BackendError::Http(error.to_string()))?
        };
        let request_url = if query.is_empty() {
            url
        } else {
            format!("{url}?{query}")
        };

        let mut request = match method {
            "GET" => self.client.get(request_url),
            "POST" => self.client.post(request_url),
            "DELETE" => self.client.delete(request_url),
            _ => {
                return Err(BackendError::Http(format!(
                    "Unsupported HTTP method: {method}"
                )));
            }
        }
        .header("Authorization", &auth_value)
        .header("Accept", "application/json");

        let has_json_body = json_body.is_some();
        if let Some(body) = json_body {
            request = request.json(&body);
        }

        let response = request
            .send()
            .map_err(|error| BackendError::Http(error.to_string()))?;

        self.calls.push(CallRecord {
            method: if has_json_body {
                format!("{method}_JSON")
            } else {
                method.to_string()
            },
            path: path.to_string(),
            params,
        });

        Self::parse_body(Self::check_response(response)?)
    }

    fn request_oauth2(
        &mut self,
        method: &str,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        let token = self.ensure_bearer_token()?.to_string();
        let url = self.absolute_url(path);

        let response = match method {
            "GET" => {
                let query = if params.is_empty() {
                    String::new()
                } else {
                    serde_urlencoded::to_string(&params)
                        .map_err(|error| BackendError::Http(error.to_string()))?
                };
                let request_url = if query.is_empty() {
                    url
                } else {
                    format!("{url}?{query}")
                };
                self.client
                    .get(request_url)
                    .bearer_auth(&token)
                    .send()
                    .map_err(|error| BackendError::Http(error.to_string()))?
            }
            "POST" => self
                .client
                .post(url)
                .bearer_auth(&token)
                .form(&params)
                .send()
                .map_err(|error| BackendError::Http(error.to_string()))?,
            _ => {
                return Err(BackendError::Http(format!(
                    "Unsupported HTTP method: {method}"
                )));
            }
        };

        self.calls.push(CallRecord {
            method: format!("{method}_OAUTH2"),
            path: path.to_string(),
            params,
        });

        Self::parse_body(Self::check_response(response)?)
    }

    fn request_oauth2_json(&mut self, path: &str, body: Value) -> Result<Value, BackendError> {
        let token = self.ensure_bearer_token()?.to_string();
        let url = self.absolute_url(path);

        let response = self
            .client
            .post(url)
            .bearer_auth(&token)
            .header("Accept", "application/json")
            .json(&body)
            .send()
            .map_err(|error| BackendError::Http(error.to_string()))?;

        self.calls.push(CallRecord {
            method: "POST_JSON_OAUTH2".to_string(),
            path: path.to_string(),
            params: vec![("json".to_string(), body.to_string())],
        });

        Self::parse_body(Self::check_response(response)?)
    }

    fn ensure_bearer_token(&mut self) -> Result<String, BackendError> {
        if let Some(token) = self
            .bearer_token
            .as_deref()
            .filter(|value| !value.trim().is_empty())
        {
            return Ok(token.to_string());
        }

        let encoded_key = oauth_client::percent_encode_string(&self.credentials.consumer_key);
        let encoded_secret = oauth_client::percent_encode_string(&self.credentials.consumer_secret);
        let credentials = format!("{}:{}", encoded_key, encoded_secret);
        let basic = base64::engine::general_purpose::STANDARD.encode(credentials.as_bytes());

        let response = self
            .client
            .post("https://api.twitter.com/oauth2/token")
            .header("Authorization", format!("Basic {basic}"))
            .header(
                "Content-Type",
                "application/x-www-form-urlencoded;charset=UTF-8",
            )
            .body("grant_type=client_credentials")
            .send()
            .map_err(|error| BackendError::Http(error.to_string()))?;

        let payload_text = Self::check_response(response)?;
        let payload: Value = serde_json::from_str(&payload_text)?;

        let token = payload
            .get("access_token")
            .and_then(Value::as_str)
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                BackendError::Http("OAuth2 token response did not include access_token".to_string())
            })?
            .to_string();

        self.bearer_token = Some(token.clone());
        Ok(token)
    }

    fn absolute_url(&self, path: &str) -> String {
        if path.starts_with("http://") || path.starts_with("https://") {
            path.to_string()
        } else {
            format!("{}{}", self.base_url, path)
        }
    }

    fn check_response(response: reqwest::blocking::Response) -> Result<String, BackendError> {
        let status = response.status();
        let body = response
            .text()
            .map_err(|error| BackendError::Http(error.to_string()))?;
        if !status.is_success() {
            return Err(BackendError::Http(format_api_error(status, &body)));
        }
        Ok(body)
    }

    fn parse_body(body: String) -> Result<Value, BackendError> {
        if body.trim().is_empty() {
            return Ok(Value::Null);
        }

        match serde_json::from_str::<Value>(&body) {
            Ok(value) => Ok(value),
            Err(_) => Ok(Value::String(body)),
        }
    }
}

impl Backend for TwitterBackend {
    fn get_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.request_oauth1_signed("GET", path, params, None)
    }

    fn post_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.request_oauth1_signed("POST", path, params, None)
    }

    fn post_json_body(&mut self, path: &str, body: Value) -> Result<Value, BackendError> {
        self.request_oauth1_signed("POST", path, Vec::new(), Some(body))
    }

    fn post_json_body_oauth2(&mut self, path: &str, body: Value) -> Result<Value, BackendError> {
        self.request_oauth2_json(path, body)
    }

    fn delete_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.request_oauth1_signed("DELETE", path, params, None)
    }

    fn get_json_oauth2(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.request_oauth2("GET", path, params)
    }

    fn stream_json_lines(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
        auth: AuthScheme,
        on_event: &mut dyn FnMut(Value) -> bool,
    ) -> Result<(), BackendError> {
        self.calls.push(CallRecord {
            method: "STREAM".to_string(),
            path: path.to_string(),
            params: params.clone(),
        });

        let url = self.absolute_url(path);
        let query = serde_urlencoded::to_string(&params)
            .map_err(|error| BackendError::Http(error.to_string()))?;
        let request_url = if query.is_empty() {
            url.clone()
        } else {
            format!("{url}?{query}")
        };

        let mut request = self
            .client
            .get(request_url)
            .header("Accept", "application/json");
        match auth {
            AuthScheme::OAuth1User => {
                let consumer = Token::new(
                    self.credentials.consumer_key.as_str(),
                    self.credentials.consumer_secret.as_str(),
                );
                let access = Token::new(
                    self.credentials.token.as_str(),
                    self.credentials.secret.as_str(),
                );
                let mut other_param = ParamList::new();
                for (key, value) in &params {
                    other_param.insert(Cow::Owned(key.clone()), Cow::Owned(value.clone()));
                }
                let other = if other_param.is_empty() {
                    None
                } else {
                    Some(&other_param)
                };
                let (auth_value, _body) = oauth_client::authorization_header(
                    "GET",
                    &url,
                    &consumer,
                    Some(&access),
                    other,
                );
                request = request.header("Authorization", &auth_value);
            }
            AuthScheme::OAuth2Bearer => {
                let token = self.ensure_bearer_token()?.to_string();
                request = request.bearer_auth(token);
            }
        }

        let response = request
            .send()
            .map_err(|error| BackendError::Http(error.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().unwrap_or_default();
            return Err(BackendError::Http(format_api_error(status, &body)));
        }

        let reader = BufReader::new(response);
        for line in reader.lines() {
            let line = line.map_err(|error| BackendError::Http(error.to_string()))?;
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }

            let Ok(value) = serde_json::from_str::<Value>(trimmed) else {
                continue;
            };

            if !on_event(value) {
                break;
            }
        }

        Ok(())
    }

    fn calls(&self) -> &[CallRecord] {
        &self.calls
    }
}

#[derive(Debug, Clone, Default)]
/// In-memory backend for tests and deterministic command execution.
pub struct MockBackend {
    responses: HashMap<(String, String), VecDeque<Value>>,
    streams: HashMap<(String, String, String), VecDeque<Vec<Value>>>,
    calls: Vec<CallRecord>,
}

impl MockBackend {
    /// Creates an empty mock backend.
    pub fn new() -> Self {
        Self::default()
    }

    /// Queues a response for the given method and path.
    ///
    /// Responses are consumed in FIFO order.
    pub fn enqueue_json_response(&mut self, method: &str, path: &str, value: Value) {
        self.responses
            .entry((method.to_string(), path.to_string()))
            .or_default()
            .push_back(value);
    }

    /// Queues a full stream event batch for the given path and auth scheme.
    ///
    /// Each call to [`Backend::stream_json_lines`] consumes one queued batch.
    pub fn enqueue_stream_events(&mut self, path: &str, auth: AuthScheme, events: Vec<Value>) {
        self.streams
            .entry(("STREAM".to_string(), path.to_string(), format!("{auth:?}")))
            .or_default()
            .push_back(events);
    }
}

impl Backend for MockBackend {
    fn get_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.calls.push(CallRecord {
            method: "GET".to_string(),
            path: path.to_string(),
            params,
        });
        self.responses
            .get_mut(&("GET".to_string(), path.to_string()))
            .and_then(VecDeque::pop_front)
            .ok_or_else(|| BackendError::MissingMockResponse {
                method: "GET".to_string(),
                path: path.to_string(),
            })
    }

    fn post_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.calls.push(CallRecord {
            method: "POST".to_string(),
            path: path.to_string(),
            params,
        });
        self.responses
            .get_mut(&("POST".to_string(), path.to_string()))
            .and_then(VecDeque::pop_front)
            .ok_or_else(|| BackendError::MissingMockResponse {
                method: "POST".to_string(),
                path: path.to_string(),
            })
    }

    fn post_json_body(&mut self, path: &str, body: Value) -> Result<Value, BackendError> {
        self.calls.push(CallRecord {
            method: "POST_JSON".to_string(),
            path: path.to_string(),
            params: vec![("json".to_string(), body.to_string())],
        });
        self.responses
            .get_mut(&("POST_JSON".to_string(), path.to_string()))
            .and_then(VecDeque::pop_front)
            .or_else(|| {
                self.responses
                    .get_mut(&("POST".to_string(), path.to_string()))
                    .and_then(VecDeque::pop_front)
            })
            .ok_or_else(|| BackendError::MissingMockResponse {
                method: "POST_JSON".to_string(),
                path: path.to_string(),
            })
    }

    fn post_json_body_oauth2(&mut self, path: &str, body: Value) -> Result<Value, BackendError> {
        self.calls.push(CallRecord {
            method: "POST_JSON_OAUTH2".to_string(),
            path: path.to_string(),
            params: vec![("json".to_string(), body.to_string())],
        });
        self.responses
            .get_mut(&("POST_JSON_OAUTH2".to_string(), path.to_string()))
            .and_then(VecDeque::pop_front)
            .or_else(|| {
                self.responses
                    .get_mut(&("POST_JSON".to_string(), path.to_string()))
                    .and_then(VecDeque::pop_front)
            })
            .or_else(|| {
                self.responses
                    .get_mut(&("POST".to_string(), path.to_string()))
                    .and_then(VecDeque::pop_front)
            })
            .ok_or_else(|| BackendError::MissingMockResponse {
                method: "POST_JSON_OAUTH2".to_string(),
                path: path.to_string(),
            })
    }

    fn delete_json(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.calls.push(CallRecord {
            method: "DELETE".to_string(),
            path: path.to_string(),
            params,
        });
        self.responses
            .get_mut(&("DELETE".to_string(), path.to_string()))
            .and_then(VecDeque::pop_front)
            .ok_or_else(|| BackendError::MissingMockResponse {
                method: "DELETE".to_string(),
                path: path.to_string(),
            })
    }

    fn get_json_oauth2(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
    ) -> Result<Value, BackendError> {
        self.calls.push(CallRecord {
            method: "GET_OAUTH2".to_string(),
            path: path.to_string(),
            params,
        });
        self.responses
            .get_mut(&("GET_OAUTH2".to_string(), path.to_string()))
            .and_then(VecDeque::pop_front)
            .or_else(|| {
                self.responses
                    .get_mut(&("GET".to_string(), path.to_string()))
                    .and_then(VecDeque::pop_front)
            })
            .ok_or_else(|| BackendError::MissingMockResponse {
                method: "GET_OAUTH2".to_string(),
                path: path.to_string(),
            })
    }

    fn stream_json_lines(
        &mut self,
        path: &str,
        params: Vec<(String, String)>,
        auth: AuthScheme,
        on_event: &mut dyn FnMut(Value) -> bool,
    ) -> Result<(), BackendError> {
        self.calls.push(CallRecord {
            method: "STREAM".to_string(),
            path: path.to_string(),
            params,
        });

        let events = self
            .streams
            .get_mut(&("STREAM".to_string(), path.to_string(), format!("{auth:?}")))
            .and_then(VecDeque::pop_front)
            .ok_or_else(|| BackendError::MissingMockResponse {
                method: "STREAM".to_string(),
                path: path.to_string(),
            })?;

        for event in events {
            if !on_event(event) {
                break;
            }
        }

        Ok(())
    }

    fn calls(&self) -> &[CallRecord] {
        &self.calls
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn mock_backend_records_calls_and_dequeues_responses() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "GET",
            "/1.1/statuses/home_timeline.json",
            json!([{"id": 1}]),
        );

        let response = backend
            .get_json(
                "/1.1/statuses/home_timeline.json",
                vec![("count".to_string(), "20".to_string())],
            )
            .expect("mock response should exist");

        assert_eq!(response, json!([{"id": 1}]));
        assert_eq!(backend.calls().len(), 1);
        assert_eq!(backend.calls()[0].method, "GET");
    }

    #[test]
    fn mock_backend_streams_enqueued_events() {
        let mut backend = MockBackend::new();
        backend.enqueue_stream_events(
            "/1.1/statuses/sample.json",
            AuthScheme::OAuth1User,
            vec![json!({"id": 1}), json!({"id": 2})],
        );

        let mut seen = Vec::new();
        backend
            .stream_json_lines(
                "/1.1/statuses/sample.json",
                Vec::new(),
                AuthScheme::OAuth1User,
                &mut |event| {
                    seen.push(event);
                    true
                },
            )
            .expect("stream should be available");

        assert_eq!(seen.len(), 2);
    }

    #[test]
    fn mock_backend_supports_json_post_and_delete() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response("POST_JSON", "/2/tweets", json!({"data": {"id": "1"}}));
        backend.enqueue_json_response("DELETE", "/2/tweets/1", json!({"data": {"deleted": true}}));

        let created = backend
            .post_json_body("/2/tweets", json!({"text": "hello"}))
            .expect("json post response should exist");
        let deleted = backend
            .delete_json("/2/tweets/1", Vec::new())
            .expect("delete response should exist");

        assert_eq!(
            created.get("data").and_then(|d| d.get("id")),
            Some(&json!("1"))
        );
        assert_eq!(
            deleted.get("data").and_then(|d| d.get("deleted")),
            Some(&json!(true))
        );
        assert_eq!(backend.calls()[0].method, "POST_JSON");
        assert_eq!(backend.calls()[1].method, "DELETE");
    }

    #[test]
    fn mock_backend_supports_oauth2_json_post() {
        let mut backend = MockBackend::new();
        backend.enqueue_json_response(
            "POST_JSON_OAUTH2",
            "/2/tweets/search/stream/rules",
            json!({"data":[{"id":"11"}]}),
        );

        let response = backend
            .post_json_body_oauth2(
                "/2/tweets/search/stream/rules",
                json!({"add":[{"value":"rust","tag":"t-rust"}]}),
            )
            .expect("oauth2 json post response should exist");

        assert_eq!(
            response
                .get("data")
                .and_then(Value::as_array)
                .and_then(|items| items.first())
                .and_then(|item| item.get("id")),
            Some(&json!("11"))
        );
        assert_eq!(backend.calls()[0].method, "POST_JSON_OAUTH2");
    }

    #[test]
    fn parse_body_returns_null_for_empty_string() {
        let result = TwitterBackend::parse_body(String::new()).expect("should parse empty body");
        assert_eq!(result, Value::Null);
    }

    #[test]
    fn parse_body_returns_null_for_whitespace_only() {
        let result =
            TwitterBackend::parse_body("   \n  ".to_string()).expect("should parse whitespace");
        assert_eq!(result, Value::Null);
    }

    #[test]
    fn parse_body_returns_json_for_valid_json() {
        let result = TwitterBackend::parse_body("{\"id\": 42}".to_string())
            .expect("should parse valid json");
        assert_eq!(result, json!({"id": 42}));
    }

    #[test]
    fn parse_body_returns_string_for_non_json_text() {
        let result = TwitterBackend::parse_body("not json at all".to_string())
            .expect("should wrap non-json as string");
        assert_eq!(result, Value::String("not json at all".to_string()));
    }

    #[test]
    fn format_api_error_extracts_errors_array_messages() {
        let body = r#"{"errors":[{"message":"Not authorized"},{"message":"Rate limited"}]}"#;
        let result = format_api_error(StatusCode::FORBIDDEN, body);
        assert_eq!(result, "403: Not authorized, Rate limited");
    }

    #[test]
    fn format_api_error_extracts_title_and_detail() {
        let body = r#"{"account_id":123,"title":"CreditsDepleted","detail":"Your enrolled account [123] does not have any credits.","type":"https://api.twitter.com/2/problems/credits"}"#;
        let result = format_api_error(StatusCode::PAYMENT_REQUIRED, body);
        assert_eq!(
            result,
            "402: CreditsDepleted: Your enrolled account [123] does not have any credits."
        );
    }

    #[test]
    fn format_api_error_extracts_error_string() {
        let body = r#"{"error":"Invalid token"}"#;
        let result = format_api_error(StatusCode::UNAUTHORIZED, body);
        assert_eq!(result, "401: Invalid token");
    }

    #[test]
    fn format_api_error_falls_back_to_status_reason() {
        let result = format_api_error(StatusCode::SERVICE_UNAVAILABLE, "not json");
        assert_eq!(result, "503: Service Unavailable");
    }

    #[test]
    fn format_api_error_errors_array_takes_priority_over_title_detail() {
        let body =
            r#"{"errors":[{"message":"Specific error"}],"title":"General","detail":"Something"}"#;
        let result = format_api_error(StatusCode::BAD_REQUEST, body);
        assert_eq!(result, "400: Specific error");
    }

    #[test]
    fn format_api_error_skips_errors_array_without_messages() {
        let body = r#"{"errors":[{"detail":"no message field"}],"title":"Fallback","detail":"Used instead"}"#;
        let result = format_api_error(StatusCode::BAD_REQUEST, body);
        assert_eq!(result, "400: Fallback: Used instead");
    }

    #[test]
    fn is_retryable_true_for_5xx_and_429() {
        assert!(is_retryable(&BackendError::Http(
            "500: Internal Server Error".into()
        )));
        assert!(is_retryable(&BackendError::Http("502: Bad Gateway".into())));
        assert!(is_retryable(&BackendError::Http(
            "503: Service Unavailable".into()
        )));
        assert!(is_retryable(&BackendError::Http(
            "429: Too Many Requests".into()
        )));
    }

    #[test]
    fn is_retryable_false_for_4xx_and_non_http() {
        assert!(!is_retryable(&BackendError::Http(
            "400: Bad Request".into()
        )));
        assert!(!is_retryable(&BackendError::Http(
            "401: Unauthorized".into()
        )));
        assert!(!is_retryable(&BackendError::Http("403: Forbidden".into())));
        assert!(!is_retryable(&BackendError::Http("404: Not Found".into())));
        assert!(!is_retryable(&BackendError::Http(
            "connection refused".into()
        )));
        assert!(!is_retryable(&BackendError::MissingCredentials));
    }

    #[test]
    fn retry_with_does_not_retry_non_retryable_errors() {
        let mut attempts = 0;
        let result = retry_with(3, || {
            attempts += 1;
            Err::<(), _>(BackendError::Http("403: Forbidden".into()))
        });
        assert!(result.is_err());
        assert_eq!(attempts, 1, "should not retry 403 errors");
    }

    #[test]
    fn retry_with_retries_retryable_errors() {
        let mut attempts = 0;
        let result = retry_with(3, || {
            attempts += 1;
            Err::<(), _>(BackendError::Http("503: Service Unavailable".into()))
        });
        assert!(result.is_err());
        assert_eq!(attempts, 3, "should retry 503 errors");
    }

    #[test]
    fn mock_backend_missing_response_returns_error() {
        let mut backend = MockBackend::new();
        let result = backend.get_json("/nonexistent", vec![]);

        assert!(result.is_err());
        match result.unwrap_err() {
            BackendError::MissingMockResponse { method, path } => {
                assert_eq!(method, "GET");
                assert_eq!(path, "/nonexistent");
            }
            other => panic!("expected MissingMockResponse, got: {other:?}"),
        }
    }
}
