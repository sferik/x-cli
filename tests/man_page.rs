use std::fs;

#[test]
fn man_page_is_up_to_date() {
    let app_spec = x::manifest::legacy_app_spec();
    let command = x::manifest::clap_command(&app_spec);

    let man = clap_mangen::Man::new(command);
    let mut buf = Vec::new();
    man.render(&mut buf).expect("failed to render man page");
    let expected = String::from_utf8(buf).expect("man page is valid UTF-8");

    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/man/x.1");
    let actual = fs::read_to_string(path).unwrap_or_default();

    if actual != expected {
        fs::write(path, &expected).expect("failed to write man page");
        panic!(
            "man/x.1 was out of date and has been updated. \
             Please commit the new version."
        );
    }
}
