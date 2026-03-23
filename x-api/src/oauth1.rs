//! OAuth 1.0a signing implementation (RFC 5849).
//!
//! Provides the subset of OAuth 1.0a needed by the X CLI: signature generation,
//! Authorization header construction, and convenience functions for signed HTTP
//! requests used during the interactive authorize flow.

use base64::Engine;
use percent_encoding::{NON_ALPHANUMERIC, utf8_percent_encode};
use ring::hmac;
use ring::rand::{SecureRandom, SystemRandom};
use std::borrow::Cow;
use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// RFC 5849 §3.6 percent-encode set: everything except ALPHA, DIGIT, `-`, `.`, `_`, `~`.
const RFC5849: &percent_encoding::AsciiSet = &NON_ALPHANUMERIC
    .remove(b'-')
    .remove(b'.')
    .remove(b'_')
    .remove(b'~');

/// Percent-encodes a string per RFC 5849 §3.6.
pub fn percent_encode(s: &str) -> String {
    utf8_percent_encode(s, RFC5849).to_string()
}

/// An OAuth token (consumer or access) consisting of a key and secret.
#[derive(Debug, Clone)]
pub struct Token<'a> {
    /// The token key.
    pub key: Cow<'a, str>,
    /// The token secret.
    pub secret: Cow<'a, str>,
}

impl<'a> Token<'a> {
    /// Creates a new token from key and secret.
    pub fn new(key: impl Into<Cow<'a, str>>, secret: impl Into<Cow<'a, str>>) -> Self {
        Self {
            key: key.into(),
            secret: secret.into(),
        }
    }
}

/// Ordered parameter list for OAuth signing.
pub type ParamList<'a> = BTreeMap<Cow<'a, str>, Cow<'a, str>>;

/// Generates the OAuth 1.0a `Authorization` header value for a request.
///
/// All parameters in `other_params` are included in the signature base string.
/// Parameters whose keys start with `oauth_` are additionally placed in the
/// Authorization header (e.g. `oauth_callback`, `oauth_verifier`).
pub fn authorization_header(
    method: &str,
    url: &str,
    consumer: &Token<'_>,
    access: Option<&Token<'_>>,
    other_params: Option<&ParamList<'_>>,
) -> String {
    let mut oauth_params = base_oauth_params(consumer, access);

    // Promote any oauth_* keys from other_params into the header.
    if let Some(other) = other_params {
        for (k, v) in other {
            if k.starts_with("oauth_") {
                oauth_params.insert(k.to_string(), v.to_string());
            }
        }
    }

    let signature = compute_signature(method, url, consumer, access, &oauth_params, other_params);
    oauth_params.insert("oauth_signature".to_string(), signature);
    format_header(&oauth_params)
}

/// Makes a signed OAuth 1.0a POST request and returns the response body.
///
/// `oauth_*` parameters from `other_params` are sent in the Authorization
/// header; remaining parameters are sent as a form-encoded body.
pub fn post(
    url: &str,
    consumer: &Token<'_>,
    access: Option<&Token<'_>>,
    other_params: Option<&ParamList<'_>>,
) -> Result<String, String> {
    let auth = authorization_header("POST", url, consumer, access, other_params);

    let body: String = other_params
        .into_iter()
        .flat_map(|p| p.iter())
        .filter(|(k, _)| !k.starts_with("oauth_"))
        .map(|(k, v)| format!("{}={}", percent_encode(k), percent_encode(v)))
        .collect::<Vec<_>>()
        .join("&");

    reqwest::blocking::Client::new()
        .post(url)
        .header("Authorization", &auth)
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .and_then(|r| r.error_for_status())
        .and_then(|r| r.text())
        .map_err(|e| e.to_string())
}

/// Makes a signed OAuth 1.0a GET request and returns the response body.
///
/// `oauth_*` parameters from `other_params` are sent in the Authorization
/// header; remaining parameters are appended to the URL as a query string.
pub fn get(
    url: &str,
    consumer: &Token<'_>,
    access: Option<&Token<'_>>,
    other_params: Option<&ParamList<'_>>,
) -> Result<String, String> {
    let auth = authorization_header("GET", url, consumer, access, other_params);

    let query: String = other_params
        .into_iter()
        .flat_map(|p| p.iter())
        .filter(|(k, _)| !k.starts_with("oauth_"))
        .map(|(k, v)| format!("{}={}", percent_encode(k), percent_encode(v)))
        .collect::<Vec<_>>()
        .join("&");

    let request_url = if query.is_empty() {
        url.to_string()
    } else {
        format!("{url}?{query}")
    };

    reqwest::blocking::Client::new()
        .get(&request_url)
        .header("Authorization", &auth)
        .send()
        .and_then(|r| r.error_for_status())
        .and_then(|r| r.text())
        .map_err(|e| e.to_string())
}

// ── internal helpers ────────────────────────────────────────────────────

fn base_oauth_params(consumer: &Token<'_>, access: Option<&Token<'_>>) -> BTreeMap<String, String> {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system clock before UNIX epoch")
        .as_secs()
        .to_string();

    let mut params = BTreeMap::new();
    params.insert("oauth_consumer_key".to_string(), consumer.key.to_string());
    params.insert("oauth_nonce".to_string(), generate_nonce());
    params.insert(
        "oauth_signature_method".to_string(),
        "HMAC-SHA1".to_string(),
    );
    params.insert("oauth_timestamp".to_string(), timestamp);
    params.insert("oauth_version".to_string(), "1.0".to_string());
    if let Some(token) = access {
        params.insert("oauth_token".to_string(), token.key.to_string());
    }
    params
}

fn generate_nonce() -> String {
    let rng = SystemRandom::new();
    let mut bytes = [0u8; 32];
    rng.fill(&mut bytes)
        .expect("system random number generation failed");
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes)
}

fn compute_signature(
    method: &str,
    url: &str,
    consumer: &Token<'_>,
    access: Option<&Token<'_>>,
    oauth_params: &BTreeMap<String, String>,
    other_params: Option<&ParamList<'_>>,
) -> String {
    // Collect all params for the signature base string (RFC 5849 §3.4.1.3).
    let mut all_params: BTreeMap<String, String> = oauth_params.clone();
    if let Some(other) = other_params {
        for (k, v) in other {
            all_params.insert(k.to_string(), v.to_string());
        }
    }

    // Normalized parameter string (RFC 5849 §3.4.1.3.2).
    let param_string: String = all_params
        .iter()
        .map(|(k, v)| format!("{}={}", percent_encode(k), percent_encode(v)))
        .collect::<Vec<_>>()
        .join("&");

    // Signature base string (RFC 5849 §3.4.1).
    let base_string = format!(
        "{}&{}&{}",
        method.to_ascii_uppercase(),
        percent_encode(url),
        percent_encode(&param_string)
    );

    // Signing key (RFC 5849 §3.4.2).
    let token_secret = access.map(|t| t.secret.as_ref()).unwrap_or("");
    let signing_key = format!(
        "{}&{}",
        percent_encode(&consumer.secret),
        percent_encode(token_secret)
    );

    let key = hmac::Key::new(hmac::HMAC_SHA1_FOR_LEGACY_USE_ONLY, signing_key.as_bytes());
    let tag = hmac::sign(&key, base_string.as_bytes());
    base64::engine::general_purpose::STANDARD.encode(tag.as_ref())
}

fn format_header(oauth_params: &BTreeMap<String, String>) -> String {
    let pairs: String = oauth_params
        .iter()
        .map(|(k, v)| format!("{}=\"{}\"", k, percent_encode(v)))
        .collect::<Vec<_>>()
        .join(", ");
    format!("OAuth {pairs}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn percent_encode_leaves_unreserved_chars() {
        assert_eq!(percent_encode("abc-._~123"), "abc-._~123");
    }

    #[test]
    fn percent_encode_encodes_special_chars() {
        assert_eq!(percent_encode("hello world"), "hello%20world");
        assert_eq!(percent_encode("a&b=c"), "a%26b%3Dc");
        assert_eq!(percent_encode("100%"), "100%25");
    }

    #[test]
    fn authorization_header_contains_required_params() {
        let consumer = Token::new("key", "secret");
        let access = Token::new("token", "token_secret");
        let header = authorization_header(
            "GET",
            "https://example.com/api",
            &consumer,
            Some(&access),
            None,
        );

        assert!(header.starts_with("OAuth "));
        assert!(header.contains("oauth_consumer_key=\"key\""));
        assert!(header.contains("oauth_token=\"token\""));
        assert!(header.contains("oauth_signature_method=\"HMAC-SHA1\""));
        assert!(header.contains("oauth_version=\"1.0\""));
        assert!(header.contains("oauth_signature="));
        assert!(header.contains("oauth_nonce="));
        assert!(header.contains("oauth_timestamp="));
    }

    #[test]
    fn authorization_header_promotes_oauth_other_params() {
        let consumer = Token::new("key", "secret");
        let mut params = ParamList::new();
        params.insert("oauth_callback".into(), "oob".into());
        let header = authorization_header(
            "POST",
            "https://example.com/oauth",
            &consumer,
            None,
            Some(&params),
        );

        assert!(header.contains("oauth_callback=\"oob\""));
    }

    #[test]
    fn authorization_header_excludes_non_oauth_params() {
        let consumer = Token::new("key", "secret");
        let access = Token::new("token", "token_secret");
        let mut params = ParamList::new();
        params.insert("user.fields".into(), "username".into());
        let header = authorization_header(
            "GET",
            "https://example.com/api",
            &consumer,
            Some(&access),
            Some(&params),
        );

        assert!(!header.contains("user.fields"));
    }

    #[test]
    fn token_new_accepts_str_and_string() {
        let t1 = Token::new("key", "secret");
        let t2 = Token::new("key".to_string(), "secret".to_string());
        assert_eq!(t1.key, t2.key);
        assert_eq!(t1.secret, t2.secret);
    }

    /// Validates our signature against the reference example from RFC 5849 §1.2.
    #[test]
    fn signature_matches_known_vector() {
        // Use fixed values instead of random nonce/timestamp.
        let consumer = Token::new("dpf43f3p2l4k3l03", "kd94hf93k423kf44");
        let access = Token::new("nnch734d00sl2jdk", "pfkkdhi9sl3r4s00");

        let mut oauth_params = BTreeMap::new();
        oauth_params.insert(
            "oauth_consumer_key".to_string(),
            "dpf43f3p2l4k3l03".to_string(),
        );
        oauth_params.insert("oauth_token".to_string(), "nnch734d00sl2jdk".to_string());
        oauth_params.insert(
            "oauth_signature_method".to_string(),
            "HMAC-SHA1".to_string(),
        );
        oauth_params.insert("oauth_timestamp".to_string(), "1191242096".to_string());
        oauth_params.insert("oauth_nonce".to_string(), "kllo9940pd9333jh".to_string());
        oauth_params.insert("oauth_version".to_string(), "1.0".to_string());

        let mut other = ParamList::new();
        other.insert("size".into(), "original".into());
        other.insert("file".into(), "vacation.jpg".into());

        let sig = compute_signature(
            "GET",
            "http://photos.example.net/photos",
            &consumer,
            Some(&access),
            &oauth_params,
            Some(&other),
        );

        assert_eq!(sig, "tR3+Ty81lMeYAr/Fid0kMTYa/WM=");
    }
}
