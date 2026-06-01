use std::env;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct DbPaths {
    pub app_root: PathBuf,
    pub primary: PathBuf,
    pub cache: PathBuf,
}

impl DbPaths {
    pub fn from_env() -> anyhow::Result<Self> {
        let app_root = env::var("AGRR_APP_ROOT")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
            });
        let primary = env::var("AGRR_SQLITE_PATH")
            .map(PathBuf::from)
            .unwrap_or_else(|_| app_root.join("storage/development.sqlite3"));
        let cache = env::var("AGRR_CACHE_SQLITE_PATH")
            .map(PathBuf::from)
            .unwrap_or_else(|_| app_root.join("storage/development_cache.sqlite3"));
        Ok(Self {
            app_root,
            primary,
            cache,
        })
    }

}

pub fn repo_relative(app_root: &Path, rel: &str) -> PathBuf {
    app_root.join(rel)
}
