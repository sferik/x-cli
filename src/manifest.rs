//! CLI manifest extraction and clap command generation.

use clap::builder::PossibleValuesParser;
use clap::{Arg, ArgAction, Command};
use regex::Regex;
use std::collections::HashMap;

const CLI_RB: &str = include_str!("../legacy/lib/t/cli.rb");
const COLLECTION_RB: &str = include_str!("../legacy/lib/t/collection.rb");
const DELETE_RB: &str = include_str!("../legacy/lib/t/delete.rb");
const LIST_RB: &str = include_str!("../legacy/lib/t/list.rb");
const SEARCH_RB: &str = include_str!("../legacy/lib/t/search.rb");
const SET_RB: &str = include_str!("../legacy/lib/t/set.rb");
const STREAM_RB: &str = include_str!("../legacy/lib/t/stream.rb");

#[derive(Debug, Clone, PartialEq, Eq)]
/// Description of one CLI option sourced from legacy Ruby definitions.
pub struct OptionSpec {
    /// Long option name without `--`.
    pub long: String,
    /// Optional short option character.
    pub short: Option<char>,
    /// Whether the option accepts a value.
    pub takes_value: bool,
    /// Optional placeholder used in help output.
    pub value_name: Option<String>,
    /// Allowed values for this option.
    pub possible_values: Vec<String>,
    /// Optional default value.
    pub default_value: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
/// Specification of one command or subcommand.
pub struct CommandSpec {
    /// Displayed command token used on the CLI.
    pub name: String,
    /// Ruby method symbol backing this command.
    pub method: String,
    /// One-line help text.
    pub about: String,
    /// Minimum positional argument count required by the command.
    pub min_args: usize,
    /// Command-local options.
    pub options: Vec<OptionSpec>,
    /// Command aliases.
    pub aliases: Vec<String>,
    /// Optional class name used to load nested subcommands.
    pub subcommand_class: Option<String>,
    /// Resolved nested subcommands.
    pub subcommands: Vec<CommandSpec>,
}

#[derive(Debug, Clone)]
/// Top-level specification for the `x` CLI.
pub struct AppSpec {
    /// Global class options shared by commands.
    pub class_options: Vec<OptionSpec>,
    /// Top-level commands.
    pub commands: Vec<CommandSpec>,
    /// Version aliases extracted from the legacy command mapping.
    pub version_aliases: Vec<String>,
}

#[derive(Debug, Clone)]
struct ClassSpec {
    class_options: Vec<OptionSpec>,
    commands: Vec<CommandSpec>,
}

/// Parses legacy Ruby CLI classes into an [`AppSpec`] command manifest.
pub fn legacy_app_spec() -> AppSpec {
    let mut classes = HashMap::new();
    classes.insert("CLI".to_string(), parse_class(CLI_RB));
    classes.insert("Collection".to_string(), parse_class(COLLECTION_RB));
    classes.insert("Delete".to_string(), parse_class(DELETE_RB));
    classes.insert("List".to_string(), parse_class(LIST_RB));
    classes.insert("Search".to_string(), parse_class(SEARCH_RB));
    classes.insert("Set".to_string(), parse_class(SET_RB));
    classes.insert("Stream".to_string(), parse_class(STREAM_RB));

    let class_options = classes
        .get("CLI")
        .map(|c| c.class_options.clone())
        .unwrap_or_default();

    let mut commands = resolve_commands("CLI", &classes);
    let mut version_aliases = Vec::new();

    if let Some(version_cmd) = commands
        .iter_mut()
        .find(|command| command.method == "version")
    {
        let mut retained = Vec::new();
        for alias in &version_cmd.aliases {
            if alias.starts_with('-') {
                version_aliases.push(alias.clone());
            } else {
                retained.push(alias.clone());
            }
        }
        version_cmd.aliases = retained;
    }

    AppSpec {
        class_options,
        commands,
        version_aliases,
    }
}

/// Builds a `clap::Command` tree from an [`AppSpec`].
pub fn clap_command(app_spec: &AppSpec) -> Command {
    let mut command = Command::new("x")
        .disable_help_subcommand(true)
        .disable_version_flag(true)
        .allow_external_subcommands(false)
        .arg_required_else_help(false)
        .subcommand_required(false);

    for class_option in &app_spec.class_options {
        command = command.arg(build_arg(class_option, true));
    }

    // Ruby exposes -v/--version via aliasing to the version command.
    if app_spec
        .version_aliases
        .iter()
        .any(|alias| alias == "-v" || alias == "--version")
    {
        command = command.arg(
            Arg::new("version_flag")
                .short('v')
                .long("version")
                .global(true)
                .help("Show version")
                .action(ArgAction::SetTrue),
        );
    }

    for subcommand in &app_spec.commands {
        command = command.subcommand(build_subcommand(subcommand));
    }

    command
}

/// Flattens a command tree into `(path, leaf_command)` tuples.
pub fn flatten_leaf_commands(commands: &[CommandSpec]) -> Vec<(Vec<String>, CommandSpec)> {
    let mut leaves = Vec::new();
    for command in commands {
        collect_leaf_commands(command, &mut Vec::new(), &mut leaves);
    }
    leaves
}

fn collect_leaf_commands(
    command: &CommandSpec,
    parent_path: &mut Vec<String>,
    leaves: &mut Vec<(Vec<String>, CommandSpec)>,
) {
    parent_path.push(command.name.clone());

    if command.subcommands.is_empty() {
        leaves.push((parent_path.clone(), command.clone()));
    } else {
        for subcommand in &command.subcommands {
            collect_leaf_commands(subcommand, parent_path, leaves);
        }
    }

    parent_path.pop();
}

fn resolve_commands(class_name: &str, classes: &HashMap<String, ClassSpec>) -> Vec<CommandSpec> {
    let Some(class_spec) = classes.get(class_name) else {
        return Vec::new();
    };

    class_spec
        .commands
        .iter()
        .map(|command| {
            let mut cloned = command.clone();
            if let Some(subcommand_class) = &cloned.subcommand_class {
                cloned.subcommands = resolve_commands(subcommand_class, classes);
            }
            cloned
        })
        .collect()
}

fn parse_class(source: &str) -> ClassSpec {
    let class_option_re =
        Regex::new(r#"^\s*class_option\s+\"([^\"]+)\"(.*)$"#).expect("class_option regex is valid");
    let desc_re =
        Regex::new(r#"^\s*desc\s+\"([^\"]+)\"\s*,\s*\"([^\"]*)\""#).expect("desc regex is valid");
    let method_option_re = Regex::new(r#"^\s*method_option\s+\"([^\"]+)\"(.*)$"#)
        .expect("method_option regex is valid");
    let def_re = Regex::new(r#"^\s*def\s+([a-zA-Z0-9_!?]+)"#).expect("def regex is valid");
    let map_re = Regex::new(r#"^\s*map\s+%w\[(.*?)\]\s*=>\s*:([a-zA-Z0-9_!?]+)"#)
        .expect("map regex is valid");
    let subcommand_re = Regex::new(r#"^\s*subcommand\s+\"([^\"]+)\"\s*,\s*T::([A-Za-z0-9_]+)"#)
        .expect("subcommand regex is valid");
    let constants = parse_constants(source);

    let mut class_options = Vec::new();
    let mut commands = Vec::new();
    let mut method_index = HashMap::<String, usize>::new();

    let mut pending_desc: Option<(String, String)> = None;
    let mut pending_options: Vec<OptionSpec> = Vec::new();

    for raw_line in source.lines() {
        let line = raw_line.trim();

        if let Some(capture) = class_option_re.captures(line) {
            class_options.push(parse_option(
                capture
                    .get(1)
                    .expect("capture group exists")
                    .as_str()
                    .to_string(),
                capture.get(2).map(|m| m.as_str()).unwrap_or(""),
                &constants,
            ));
            continue;
        }

        if let Some(capture) = desc_re.captures(line) {
            let signature = capture
                .get(1)
                .expect("capture group exists")
                .as_str()
                .to_string();
            let about = capture
                .get(2)
                .expect("capture group exists")
                .as_str()
                .to_string();
            pending_desc = Some((
                interpolate_ruby_constants(&signature, &constants),
                interpolate_ruby_constants(&about, &constants),
            ));
            pending_options.clear();
            continue;
        }

        if let Some(capture) = method_option_re.captures(line) {
            pending_options.push(parse_option(
                capture
                    .get(1)
                    .expect("capture group exists")
                    .as_str()
                    .to_string(),
                capture.get(2).map(|m| m.as_str()).unwrap_or(""),
                &constants,
            ));
            continue;
        }

        if let Some(capture) = subcommand_re.captures(line) {
            if let Some((signature, about)) = pending_desc.take() {
                let (name, min_args) = parse_signature(&signature);
                let command = CommandSpec {
                    method: capture
                        .get(1)
                        .expect("capture group exists")
                        .as_str()
                        .to_string(),
                    name,
                    about,
                    min_args,
                    options: std::mem::take(&mut pending_options),
                    aliases: Vec::new(),
                    subcommand_class: Some(
                        capture
                            .get(2)
                            .expect("capture group exists")
                            .as_str()
                            .to_string(),
                    ),
                    subcommands: Vec::new(),
                };
                let idx = commands.len();
                method_index.insert(command.method.clone(), idx);
                commands.push(command);
            }
            continue;
        }

        if let Some(capture) = def_re.captures(line) {
            if let Some((signature, about)) = pending_desc.take() {
                let (name, min_args) = parse_signature(&signature);
                let method = capture
                    .get(1)
                    .expect("capture group exists")
                    .as_str()
                    .to_string();
                let command = CommandSpec {
                    method: method.clone(),
                    name,
                    about,
                    min_args,
                    options: std::mem::take(&mut pending_options),
                    aliases: Vec::new(),
                    subcommand_class: None,
                    subcommands: Vec::new(),
                };
                let idx = commands.len();
                method_index.insert(method, idx);
                commands.push(command);
            }
            continue;
        }

        if let Some(capture) = map_re.captures(line) {
            let aliases = capture
                .get(1)
                .expect("capture group exists")
                .as_str()
                .split_whitespace()
                .map(ToString::to_string)
                .collect::<Vec<_>>();
            let method = capture
                .get(2)
                .expect("capture group exists")
                .as_str()
                .to_string();
            if let Some(index) = method_index.get(&method).copied() {
                commands[index].aliases.extend(aliases);
            }
            continue;
        }
    }

    ClassSpec {
        class_options,
        commands,
    }
}

fn parse_signature(signature: &str) -> (String, usize) {
    let mut tokens = signature.split_whitespace();
    let name = tokens.next().unwrap_or_default().to_string();
    let mut min_args = 0;

    for token in tokens {
        let cleaned = token.trim_matches(',');

        // Declaration sugar for subcommands: "SUBCOMMAND ...ARGS"
        if cleaned == "SUBCOMMAND" || cleaned == "...ARGS" {
            continue;
        }

        let optional = cleaned.starts_with('[') && cleaned.ends_with(']');
        let inner = cleaned.trim_start_matches('[').trim_end_matches(']');
        if inner.is_empty() {
            continue;
        }

        if inner.contains("...") {
            if !optional {
                min_args += 1;
            }
            continue;
        }

        if !optional {
            min_args += 1;
        }
    }

    (name, min_args)
}

fn parse_option(
    name: String,
    option_tail: &str,
    constants: &HashMap<String, String>,
) -> OptionSpec {
    let short = Regex::new(r#"aliases:\s*\"-([A-Za-z])\""#)
        .expect("short option regex is valid")
        .captures(option_tail)
        .and_then(|capture| capture.get(1))
        .and_then(|match_| match_.as_str().chars().next());

    let option_type = Regex::new(r#"type:\s*:(\w+)"#)
        .expect("type regex is valid")
        .captures(option_tail)
        .and_then(|capture| capture.get(1))
        .map(|match_| match_.as_str().to_string());

    let possible_values = Regex::new(r#"enum:\s*%w\[(.*?)\]"#)
        .expect("enum regex is valid")
        .captures(option_tail)
        .and_then(|capture| capture.get(1))
        .map(|match_| {
            match_
                .as_str()
                .split_whitespace()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    let value_name = Regex::new(r#"banner:\s*\"([^\"]+)\""#)
        .expect("banner regex is valid")
        .captures(option_tail)
        .and_then(|capture| capture.get(1))
        .map(|match_| match_.as_str().to_string());

    let default_value = parse_default_value(option_tail, constants);

    let takes_value = match option_type.as_deref() {
        Some("boolean") => false,
        Some(_) => true,
        None => !possible_values.is_empty(),
    };

    OptionSpec {
        long: name,
        short,
        takes_value,
        value_name,
        possible_values,
        default_value,
    }
}

fn parse_default_value(option_tail: &str, constants: &HashMap<String, String>) -> Option<String> {
    let quoted_re =
        Regex::new(r#"default:\s*\"([^\"]*)\""#).expect("default quoted regex is valid");
    if let Some(capture) = quoted_re.captures(option_tail) {
        return capture.get(1).map(|match_| match_.as_str().to_string());
    }

    let bare_re = Regex::new(r#"default:\s*([0-9]+|nil)"#).expect("default bare regex is valid");
    if let Some(capture) = bare_re.captures(option_tail) {
        let value = capture
            .get(1)
            .expect("capture group exists")
            .as_str()
            .to_string();
        if value == "nil" {
            return None;
        }
        return Some(value);
    }

    let const_re =
        Regex::new(r#"default:\s*([A-Z][A-Z0-9_]*)"#).expect("default const regex is valid");
    if let Some(capture) = const_re.captures(option_tail) {
        let key = capture
            .get(1)
            .expect("capture group exists")
            .as_str()
            .to_string();
        return constants.get(&key).cloned();
    }

    None
}

fn parse_constants(source: &str) -> HashMap<String, String> {
    let constant_re =
        Regex::new(r#"^\s*([A-Z][A-Z0-9_]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([0-9]+))"#)
            .expect("constant regex is valid");
    let mut constants = HashMap::new();

    for raw_line in source.lines() {
        let line = raw_line.trim();
        if let Some(capture) = constant_re.captures(line) {
            let key = capture
                .get(1)
                .expect("capture group exists")
                .as_str()
                .to_string();
            let value = capture
                .get(2)
                .or_else(|| capture.get(3))
                .or_else(|| capture.get(4))
                .map(|match_| match_.as_str().to_string())
                .unwrap_or_default();
            constants.insert(key, value);
        }
    }

    constants
}

fn interpolate_ruby_constants(input: &str, constants: &HashMap<String, String>) -> String {
    let interpolation_re =
        Regex::new(r#"\#\{([A-Z][A-Z0-9_]*)\}"#).expect("interpolation regex is valid");

    interpolation_re
        .replace_all(input, |capture: &regex::Captures<'_>| {
            let key = capture
                .get(1)
                .expect("capture group exists")
                .as_str()
                .to_string();
            constants.get(&key).cloned().unwrap_or_else(|| {
                capture
                    .get(0)
                    .expect("capture group exists")
                    .as_str()
                    .to_string()
            })
        })
        .to_string()
}

fn build_subcommand(command_spec: &CommandSpec) -> Command {
    let mut command = Command::new(command_spec.name.clone())
        .about(command_spec.about.clone())
        .disable_help_subcommand(true);

    for alias in &command_spec.aliases {
        if !alias.starts_with('-') {
            command = command.visible_alias(alias);
        }
    }

    for option in &command_spec.options {
        command = command.arg(build_arg(option, false));
    }

    if command_spec.subcommands.is_empty() {
        command = command.arg(
            Arg::new("args")
                .value_name("ARGS")
                .num_args(command_spec.min_args..)
                .action(ArgAction::Append),
        );
    } else {
        for subcommand in &command_spec.subcommands {
            command = command.subcommand(build_subcommand(subcommand));
        }
    }

    command
}

fn build_arg(option_spec: &OptionSpec, global: bool) -> Arg {
    let canonical_long = option_spec.long.replace('_', "-");
    let mut arg = Arg::new(option_spec.long.clone()).long(canonical_long.clone());

    if canonical_long != option_spec.long {
        arg = arg.visible_alias(option_spec.long.clone());
    }

    if let Some(short) = option_spec.short {
        arg = arg.short(short);
    }

    if global {
        arg = arg.global(true);
    }

    if option_spec.takes_value {
        arg = arg.action(ArgAction::Set).num_args(1);

        if !option_spec.possible_values.is_empty() {
            arg = arg.value_parser(PossibleValuesParser::new(
                option_spec.possible_values.clone(),
            ));
        }

        if let Some(value_name) = &option_spec.value_name {
            arg = arg.value_name(value_name.clone());
        }

        if let Some(default_value) = &option_spec.default_value {
            arg = arg.default_value(default_value.clone());
        }
    } else {
        arg = arg.action(ArgAction::SetTrue);
    }

    arg
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_cli_top_level_commands() {
        let app = legacy_app_spec();
        let names = app
            .commands
            .iter()
            .map(|command| command.name.clone())
            .collect::<Vec<_>>();

        assert!(names.contains(&"timeline".to_string()));
        assert!(names.contains(&"delete".to_string()));
        assert!(names.contains(&"stream".to_string()));
        assert!(names.contains(&"version".to_string()));
    }

    #[test]
    fn collects_version_aliases_from_ruby_map() {
        let app = legacy_app_spec();

        assert!(app.version_aliases.contains(&"-v".to_string()));
        assert!(app.version_aliases.contains(&"--version".to_string()));
    }

    #[test]
    fn clap_structure_is_valid() {
        let app = legacy_app_spec();
        let command = clap_command(&app);
        command.debug_assert();
    }

    #[test]
    fn interpolates_constants_in_command_help_and_option_defaults() {
        let app = legacy_app_spec();
        let timeline = app
            .commands
            .iter()
            .find(|command| command.name == "timeline")
            .expect("timeline command exists");

        assert_eq!(
            timeline.about,
            "Returns the 20 most recent Tweets posted by a user."
        );

        let number_option = timeline
            .options
            .iter()
            .find(|option| option.long == "number")
            .expect("timeline --number option exists");
        assert_eq!(number_option.default_value.as_deref(), Some("20"));

        let search = app
            .commands
            .iter()
            .find(|command| command.name == "search")
            .expect("search command exists");
        let search_all = search
            .subcommands
            .iter()
            .find(|command| command.name == "all")
            .expect("search all command exists");
        assert_eq!(
            search_all.about,
            "Returns the 20 most recent Tweets that match the specified query."
        );
    }
}
