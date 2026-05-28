//! Ruby: `Domain::Shared::ValidationErrors`

use std::collections::BTreeMap;

/// Attribute-keyed validation messages (Ruby `ValidationErrors`).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ValidationErrors {
    messages_by_attribute: BTreeMap<String, Vec<String>>,
}

impl ValidationErrors {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add(&mut self, attribute: impl Into<String>, message: impl Into<String>) {
        let key = attribute.into();
        self.messages_by_attribute
            .entry(key)
            .or_default()
            .push(message.into());
    }

    pub fn get(&self, attribute: &str) -> Vec<String> {
        self.messages_by_attribute
            .get(attribute)
            .cloned()
            .unwrap_or_default()
    }

    pub fn is_empty(&self) -> bool {
        self.messages_by_attribute
            .values()
            .all(|msgs| msgs.is_empty())
    }

    pub fn any(&self) -> bool {
        !self.is_empty()
    }

    pub fn count(&self) -> usize {
        self.full_messages().len()
    }

    pub fn messages(&self) -> BTreeMap<String, Vec<String>> {
        self.messages_by_attribute
            .iter()
            .filter(|(_, msgs)| !msgs.is_empty())
            .map(|(k, msgs)| (k.clone(), msgs.clone()))
            .collect()
    }

    pub fn full_messages(&self) -> Vec<String> {
        self.messages()
            .into_values()
            .flatten()
            .collect()
    }

    /// Ruby: `ValidationErrors.from_errors_like`
    pub fn from_errors_like(obj: ErrorsLike<'_>) -> Self {
        let mut ve = ValidationErrors::new();
        match obj {
            ErrorsLike::None => {}
            ErrorsLike::ValidationErrors(e) => return e.clone(),
            ErrorsLike::Messages(arr) => {
                for m in arr {
                    ve.add("base", m);
                }
            }
            ErrorsLike::Hash(map) => {
                for (attr, msgs) in map {
                    for m in msgs {
                        if !m.is_empty() {
                            ve.add(attr.clone(), m.clone());
                        }
                    }
                }
            }
        }
        ve
    }
}

pub enum ErrorsLike<'a> {
    None,
    ValidationErrors(&'a ValidationErrors),
    Messages(&'a [String]),
    Hash(&'a BTreeMap<String, Vec<String>>),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_and_full_messages() {
        let mut e = ValidationErrors::new();
        e.add("name", "can't be blank");
        assert_eq!(e.get("name"), vec!["can't be blank"]);
        assert_eq!(e.full_messages(), vec!["can't be blank"]);
        assert!(e.any());
    }
}
