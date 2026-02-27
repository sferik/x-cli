//! Loading, saving, and mutating `~/.xrc` profile data.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::ffi::OsStr;
use std::fs::File;
use std::io::{BufReader, BufWriter};
use std::path::{Path, PathBuf};
/// Credential record used by profile entries.
pub use x_api::backend::Credentials;

#[derive(Debug, thiserror::Error)]
/// Errors returned while reading or mutating profile data.
pub enum RcFileError {
    /// Filesystem I/O failure.
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
    /// YAML serialization/deserialization failure.
    #[error("YAML parse error: {0}")]
    Yaml(#[from] serde_yaml::Error),
    /// The requested username did not match any configured profile.
    #[error("Username {0} is not found.")]
    UsernameNotFound(String),
    /// The requested username matched multiple configured profiles.
    #[error("Username {input} is ambiguous, matching {matches}")]
    UsernameAmbiguous {
        /// User input that produced multiple matches.
        input: String,
        /// Comma-separated matching profiles.
        matches: String,
    },
    /// A resolved profile name was missing from the profile map.
    #[error("Profile {0} is missing from the rc file")]
    MissingProfile(String),
    /// The requested consumer key was not configured for the profile.
    #[error("Consumer key {key} is missing for profile {profile}")]
    MissingConsumerKey {
        /// Profile name.
        profile: String,
        /// Missing consumer key.
        key: String,
    },
    /// The profile exists but has no consumer keys configured.
    #[error("Profile {0} has no configured consumer keys")]
    EmptyProfileKeys(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
/// Serializable contents of an rc file.
pub struct RcData {
    /// Global configuration section.
    #[serde(default)]
    pub configuration: Configuration,
    /// Profile map keyed by username, then consumer key.
    #[serde(default)]
    pub profiles: BTreeMap<String, BTreeMap<String, Credentials>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
/// Global configuration values stored in the rc file.
pub struct Configuration {
    /// Active profile `(username, consumer_key)` selection.
    #[serde(
        default,
        rename = "default_profile",
        skip_serializing_if = "Option::is_none"
    )]
    pub default_profile: Option<(String, String)>,
}

#[derive(Debug, Clone, Default)]
/// In-memory representation of an rc file.
pub struct RcFile {
    data: RcData,
}

impl RcFile {
    /// Loads rc data from `path`.
    ///
    /// If the path does not exist and is named `.xrc`, `.trc` is used as a fallback.
    /// Missing files return an empty default configuration.
    pub fn load(path: &Path) -> Result<Self, RcFileError> {
        let resolved_path = if path.exists() {
            path.to_path_buf()
        } else if let Some(legacy_path) = legacy_profile_fallback(path) {
            if legacy_path.exists() {
                legacy_path
            } else {
                return Ok(Self::default());
            }
        } else {
            return Ok(Self::default());
        };

        let file = File::open(resolved_path)?;
        let reader = BufReader::new(file);
        let data = serde_yaml::from_reader(reader)?;

        Ok(Self { data })
    }

    /// Saves rc data to `path`, creating parent directories if required.
    ///
    /// On Unix, the file is written with mode `0600`.
    pub fn save(&self, path: &Path) -> Result<(), RcFileError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        migrate_legacy_profile_if_needed(path)?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            let file = std::fs::OpenOptions::new()
                .create(true)
                .write(true)
                .truncate(true)
                .mode(0o600)
                .open(path)?;
            let writer = BufWriter::new(file);
            serde_yaml::to_writer(writer, &self.data)?;
        }

        #[cfg(not(unix))]
        {
            let file = File::create(path)?;
            let writer = BufWriter::new(file);
            serde_yaml::to_writer(writer, &self.data)?;
        }

        Ok(())
    }

    /// Returns all configured profiles keyed by username and consumer key.
    pub fn profiles(&self) -> &BTreeMap<String, BTreeMap<String, Credentials>> {
        &self.data.profiles
    }

    /// Returns the currently active `(username, consumer_key)` pair.
    pub fn active_profile(&self) -> Option<(&str, &str)> {
        self.data
            .configuration
            .default_profile
            .as_ref()
            .map(|(username, key)| (username.as_str(), key.as_str()))
    }

    /// Returns credentials for the active profile if configured.
    pub fn active_credentials(&self) -> Option<&Credentials> {
        let (username, key) = self.active_profile()?;
        self.data.profiles.get(username)?.get(key)
    }

    /// Selects the active profile by username and optional consumer key.
    ///
    /// When `consumer_key` is `None`, the most recently ordered key in the
    /// profile map is selected.
    pub fn set_active(
        &mut self,
        username: &str,
        consumer_key: Option<&str>,
    ) -> Result<String, RcFileError> {
        let profile_name = self.find_profile_name(username)?;

        let keys = self
            .data
            .profiles
            .get(&profile_name)
            .ok_or_else(|| RcFileError::MissingProfile(profile_name.clone()))?;

        let selected_key = match consumer_key {
            Some(key) => {
                if keys.contains_key(key) {
                    key.to_string()
                } else {
                    return Err(RcFileError::MissingConsumerKey {
                        profile: profile_name,
                        key: key.to_string(),
                    });
                }
            }
            None => keys
                .keys()
                .next_back()
                .cloned()
                .ok_or_else(|| RcFileError::EmptyProfileKeys(profile_name.clone()))?,
        };

        let display_name = keys
            .get(&selected_key)
            .map(|credentials| credentials.username.clone())
            .filter(|candidate| !candidate.is_empty())
            .unwrap_or_else(|| profile_name.clone());

        self.data.configuration.default_profile = Some((display_name.clone(), selected_key));

        Ok(display_name)
    }

    /// Inserts or replaces credentials for `(screen_name, consumer_key)`.
    pub fn upsert_profile_credentials(
        &mut self,
        screen_name: &str,
        consumer_key: &str,
        credentials: Credentials,
    ) {
        self.data
            .profiles
            .entry(screen_name.to_string())
            .or_default()
            .insert(consumer_key.to_string(), credentials);
    }

    /// Deletes an account profile or a single consumer key entry.
    ///
    /// If `key` is omitted or the profile has only one key, the full profile is removed.
    pub fn delete_account(&mut self, account: &str, key: Option<&str>) -> Result<(), RcFileError> {
        let profile_name = self.find_profile_name(account)?;

        let remove_profile = {
            let Some(keys) = self.data.profiles.get_mut(&profile_name) else {
                return Err(RcFileError::MissingProfile(profile_name));
            };

            match key {
                Some(key_name) if keys.len() > 1 => {
                    keys.remove(key_name);
                    false
                }
                _ => true,
            }
        };

        if remove_profile {
            self.data.profiles.remove(&profile_name);

            if let Some((active_name, _)) = self.active_profile()
                && active_name.eq_ignore_ascii_case(&profile_name)
            {
                self.data.configuration.default_profile = None;
            }
        }

        Ok(())
    }

    fn find_profile_name(&self, username: &str) -> Result<String, RcFileError> {
        if let Some(exact_match) = self
            .data
            .profiles
            .keys()
            .find(|candidate| username.eq_ignore_ascii_case(candidate))
        {
            return Ok(exact_match.clone());
        }

        let possibilities = self
            .data
            .profiles
            .keys()
            .filter(|candidate| {
                let lhs = username.to_ascii_lowercase();
                candidate.to_ascii_lowercase().starts_with(&lhs)
            })
            .cloned()
            .collect::<Vec<_>>();

        match possibilities.as_slice() {
            [] => Err(RcFileError::UsernameNotFound(username.to_string())),
            [single] => Ok(single.clone()),
            many => Err(RcFileError::UsernameAmbiguous {
                input: username.to_string(),
                matches: many.join(", "),
            }),
        }
    }
}

/// Returns the default path used by the CLI for profile data (`~/.xrc`).
pub fn default_profile_path() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".xrc")
}

fn legacy_profile_fallback(path: &Path) -> Option<PathBuf> {
    if path.file_name() != Some(OsStr::new(".xrc")) {
        return None;
    }

    Some(path.with_file_name(".trc"))
}

fn migrate_legacy_profile_if_needed(path: &Path) -> Result<(), RcFileError> {
    let Some(legacy_path) = legacy_profile_fallback(path) else {
        return Ok(());
    };

    if path.exists() || !legacy_path.is_file() {
        return Ok(());
    }

    std::fs::copy(legacy_path, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_rc_file() -> RcFile {
        let mut profiles = BTreeMap::new();

        let mut erik_keys = BTreeMap::new();
        erik_keys.insert(
            "keyA".to_string(),
            Credentials {
                username: "erik".to_string(),
                ..Credentials::default()
            },
        );
        erik_keys.insert(
            "keyB".to_string(),
            Credentials {
                username: "erik".to_string(),
                ..Credentials::default()
            },
        );
        profiles.insert("erik".to_string(), erik_keys);

        let mut erin_keys = BTreeMap::new();
        erin_keys.insert(
            "key1".to_string(),
            Credentials {
                username: "erin".to_string(),
                ..Credentials::default()
            },
        );
        profiles.insert("erin".to_string(), erin_keys);

        RcFile {
            data: RcData {
                configuration: Configuration::default(),
                profiles,
            },
        }
    }

    #[test]
    fn set_active_accepts_case_insensitive_usernames() {
        let mut rcfile = sample_rc_file();

        let active_username = rcfile
            .set_active("ERIK", Some("keyA"))
            .expect("set active works");

        assert_eq!(active_username, "erik");
        assert_eq!(
            rcfile.active_profile(),
            Some(("erik", "keyA")),
            "default profile should be updated"
        );
    }

    #[test]
    fn set_active_rejects_ambiguous_prefix() {
        let mut rcfile = sample_rc_file();

        let error = rcfile
            .set_active("er", None)
            .expect_err("prefix should be ambiguous");

        assert!(matches!(error, RcFileError::UsernameAmbiguous { .. }));
    }

    #[test]
    fn delete_account_with_key_keeps_profile_when_multiple_keys_exist() {
        let mut rcfile = sample_rc_file();

        rcfile
            .delete_account("erik", Some("keyA"))
            .expect("delete key should succeed");

        let keys = rcfile
            .profiles()
            .get("erik")
            .expect("profile should remain");
        assert!(!keys.contains_key("keyA"));
        assert!(keys.contains_key("keyB"));
    }

    #[test]
    fn save_and_load_round_trip_yaml() {
        let tmp = tempfile::tempdir().expect("tempdir works");
        let path = tmp.path().join(".trc");

        let mut rcfile = sample_rc_file();
        rcfile
            .set_active("erik", Some("keyB"))
            .expect("set active works");
        rcfile.save(&path).expect("save should work");

        let loaded = RcFile::load(&path).expect("load should work");
        assert_eq!(loaded.active_profile(), Some(("erik", "keyB")));
        assert_eq!(loaded.profiles().len(), 2);
    }

    #[test]
    fn default_profile_path_is_xrc() {
        let path = default_profile_path();
        assert_eq!(path.file_name(), Some(OsStr::new(".xrc")));
    }

    #[test]
    fn load_falls_back_to_legacy_trc_when_xrc_is_missing() {
        let tmp = tempfile::tempdir().expect("tempdir works");
        let xrc_path = tmp.path().join(".xrc");
        let trc_path = tmp.path().join(".trc");
        std::fs::write(
            &trc_path,
            "configuration:\n  default_profile:\n    - erik\n    - keyB\nprofiles: {}\n",
        )
        .expect("legacy profile should be writable");

        let loaded = RcFile::load(&xrc_path).expect("load should use legacy fallback");
        assert_eq!(loaded.active_profile(), Some(("erik", "keyB")));
    }

    #[test]
    fn save_to_xrc_copies_legacy_trc_first_when_needed() {
        let tmp = tempfile::tempdir().expect("tempdir works");
        let xrc_path = tmp.path().join(".xrc");
        let trc_path = tmp.path().join(".trc");
        std::fs::write(&trc_path, "legacy").expect("legacy profile should be writable");

        migrate_legacy_profile_if_needed(&xrc_path).expect("legacy profile should be copied");

        let copied = std::fs::read_to_string(&xrc_path).expect("new profile should exist");
        assert_eq!(copied, "legacy");
    }
}
