use std::collections::BTreeMap;

/// Ruby `Hash` after `symbolize_keys` (string keys only in Rust).
pub type AttrMap = BTreeMap<String, AttrValue>;

#[derive(Debug, Clone, PartialEq)]
pub enum AttrValue {
    Null,
    Bool(bool),
    Int(i64),
    Str(String),
}

impl AttrValue {
    pub fn as_str(&self) -> Option<&str> {
        match self {
            AttrValue::Str(s) => Some(s.as_str()),
            _ => None,
        }
    }
}

pub fn attr_map_from_pairs<I, K, V>(pairs: I) -> AttrMap
where
    I: IntoIterator<Item = (K, V)>,
    K: Into<String>,
    V: Into<AttrValue>,
{
    pairs
        .into_iter()
        .map(|(k, v)| (k.into(), v.into()))
        .collect()
}

impl From<bool> for AttrValue {
    fn from(v: bool) -> Self {
        AttrValue::Bool(v)
    }
}

impl From<i64> for AttrValue {
    fn from(v: i64) -> Self {
        AttrValue::Int(v)
    }
}

impl From<&str> for AttrValue {
    fn from(v: &str) -> Self {
        AttrValue::Str(v.to_string())
    }
}

impl From<String> for AttrValue {
    fn from(v: String) -> Self {
        AttrValue::Str(v)
    }
}
