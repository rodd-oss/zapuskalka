use tauri::{utils::config::WebviewUrl, webview::WebviewWindowBuilder, LogicalSize};

// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_os::init())
        .setup(|app| {
            let app_ = app.handle().clone();
            let window =
                WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
                    .on_new_window(move |url, features| {
                        // Create a new window with a unique label
                        let builder = tauri::WebviewWindowBuilder::new(
                            &app_,
                            "opened-window", // Ideally use a counter for multiple windows
                            tauri::WebviewUrl::External(url.clone()),
                        )
                        .window_features(features)
                        .on_document_title_changed(|window, title| {
                            window.set_title(&title).unwrap();
                        })
                        .title(url.as_str());

                        match builder.build() {
                            Ok(window) => tauri::webview::NewWindowResponse::Create { window },
                            Err(_) => tauri::webview::NewWindowResponse::Deny,
                        }
                    })
                    .build()?;
            window.set_min_size(Some(LogicalSize::new(800, 600)))?;
            Ok(())
        })
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
