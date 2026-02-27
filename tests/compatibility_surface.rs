use x::manifest::{AppSpec, clap_command, flatten_leaf_commands, legacy_app_spec};

fn dummy_args(min_args: usize) -> Vec<String> {
    (0..min_args).map(|idx| format!("arg{}", idx + 1)).collect()
}

fn sample_value(possible_values: &[String]) -> String {
    possible_values
        .first()
        .cloned()
        .unwrap_or_else(|| "value".to_string())
}

fn assert_parse_ok(app: &AppSpec, argv: Vec<String>, context: &str) {
    let parsed = clap_command(app).try_get_matches_from(argv.clone());
    assert!(
        parsed.is_ok(),
        "{context}: {:?}",
        parsed.err().map(|err| err.to_string())
    );
}

#[test]
fn every_legacy_leaf_command_parses_with_minimum_arguments() {
    let app = legacy_app_spec();
    let leaves = flatten_leaf_commands(&app.commands);

    for (path, command_spec) in leaves {
        let mut argv = vec!["x".to_string()];
        argv.extend(path.clone());
        argv.extend(dummy_args(command_spec.min_args));

        assert_parse_ok(
            &app,
            argv,
            &format!("failed to parse canonical path {}", path.join(" ")),
        );
    }
}

#[test]
fn every_legacy_alias_parses() {
    let app = legacy_app_spec();
    let leaves = flatten_leaf_commands(&app.commands);

    for (path, command_spec) in leaves {
        let Some((_command_name, parent)) = path.split_last() else {
            continue;
        };

        for alias in command_spec
            .aliases
            .iter()
            .filter(|alias| !alias.starts_with('-'))
        {
            let mut argv = vec!["x".to_string()];
            argv.extend(parent.iter().cloned());
            argv.push(alias.clone());
            argv.extend(dummy_args(command_spec.min_args));

            assert_parse_ok(
                &app,
                argv,
                &format!(
                    "failed to parse alias '{alias}' for path {}",
                    path.join(" ")
                ),
            );
        }
    }
}

#[test]
fn every_legacy_option_long_and_short_flag_parses() {
    let app = legacy_app_spec();
    let leaves = flatten_leaf_commands(&app.commands);

    for (path, command_spec) in leaves {
        for option in &command_spec.options {
            let mut argv = vec!["x".to_string()];
            argv.extend(path.clone());

            argv.push(format!("--{}", option.long));
            if option.takes_value {
                argv.push(sample_value(&option.possible_values));
            }
            argv.extend(dummy_args(command_spec.min_args));

            assert_parse_ok(
                &app,
                argv,
                &format!(
                    "failed to parse long option --{} for {}",
                    option.long,
                    path.join(" ")
                ),
            );

            if let Some(short) = option.short {
                let mut short_argv = vec!["x".to_string()];
                short_argv.extend(path.clone());
                short_argv.push(format!("-{}", short));
                if option.takes_value {
                    short_argv.push(sample_value(&option.possible_values));
                }
                short_argv.extend(dummy_args(command_spec.min_args));

                assert_parse_ok(
                    &app,
                    short_argv,
                    &format!(
                        "failed to parse short option -{short} for {}",
                        path.join(" ")
                    ),
                );
            }
        }
    }
}

#[test]
fn global_options_and_version_aliases_parse() {
    let app = legacy_app_spec();

    let profile_parse = clap_command(&app).try_get_matches_from([
        "x",
        "--profile",
        "/tmp/test.trc",
        "--color",
        "auto",
        "accounts",
    ]);
    assert!(profile_parse.is_ok());

    let version_short = clap_command(&app).try_get_matches_from(["x", "-v"]);
    assert!(version_short.is_ok());

    let version_long = clap_command(&app).try_get_matches_from(["x", "--version"]);
    assert!(version_long.is_ok());
}
