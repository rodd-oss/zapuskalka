use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct InstalledAppInfo {
    pub id: String,
    #[serde(rename = "buildId")]
    pub build_id: String,
    #[serde(rename = "installDir")]
    pub install_dir: PathBuf,
    #[serde(rename = "storageDir")]
    pub storage_dir: PathBuf,
    pub entrypoint: String,
}
