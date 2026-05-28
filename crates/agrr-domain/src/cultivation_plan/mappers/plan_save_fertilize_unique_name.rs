//! Ruby: `Domain::CultivationPlan::Mappers::PlanSaveFertilizeUniqueName`

pub fn resolve_unique_name<F>(base_name: &str, mut exists: F) -> Option<String>
where
    F: FnMut(&str) -> bool,
{
    let first = format!("{base_name} (コピー)");
    if !exists(&first) {
        return Some(first);
    }
    let mut suffix = 2;
    loop {
        let candidate = format!("{base_name} (コピー {suffix})");
        if !exists(&candidate) {
            return Some(candidate);
        }
        suffix += 1;
    }
}
