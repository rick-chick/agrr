use std::collections::BTreeMap;

#[test]
fn apply_translation_options_replaces_all_rails_placeholders() {
    let mut opts = BTreeMap::new();
    opts.insert("start".into(), "2026-03-04".into());
    opts.insert("completion".into(), "2026-07-06".into());
    opts.insert("days".into(), "125".into());
    opts.insert("gdd".into(), "987.5".into());
    let template = "栽培期間: %{start}〜%{completion}（約%{days}日、GDD %{gdd}）";
    let out = apply_translation_options(template, &opts);
    assert!(!out.contains("%{"));
    assert_eq!(
        out,
        "栽培期間: 2026-03-04〜2026-07-06（約125日、GDD 987.5）"
    );
}

#[test]
fn apply_translation_options_replaces_repeated_placeholder_keys() {
    let mut opts = BTreeMap::new();
    opts.insert("start".into(), "2026-01-01".into());
    let out = apply_translation_options("%{start} .. %{start}", &opts);
    assert_eq!(out, "2026-01-01 .. 2026-01-01");
}

#[test]
fn apply_translation_options_leaves_unmapped_placeholders_intact() {
    let opts = BTreeMap::new();
    let out = apply_translation_options("missing %{unknown}", &opts);
    assert_eq!(out, "missing %{unknown}");
}

#[test]
fn apply_translation_options_returns_template_unchanged_when_options_empty() {
    let opts = BTreeMap::new();
    let template = "plain text without placeholders";
    assert_eq!(apply_translation_options(template, &opts), template);
}