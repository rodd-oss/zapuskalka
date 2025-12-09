use std::{collections::HashMap, path::PathBuf};

pub struct DataDirPath(pub PathBuf);

pub struct AppsRunningStatus {
    pub app2child: HashMap<String, tokio::process::Child>,
}
