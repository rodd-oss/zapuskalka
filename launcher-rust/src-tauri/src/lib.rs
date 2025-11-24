use flate2::Compression;
use flate2::{read::GzDecoder, write::GzEncoder};
use std::fs::File;
use std::io::{BufWriter, Read};
use std::path::Path;
use tar::{Archive, Builder};

// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
async fn archive_and_compress_folder(folder_path: String) -> Result<String, String> {
    let source_path = Path::new(&folder_path);

    // Check if the folder exists
    if !source_path.exists() {
        return Err(format!("Folder does not exist: {}", folder_path));
    }

    if !source_path.is_dir() {
        return Err(format!("Path is not a directory: {}", folder_path));
    }

    // Get the folder name for the archive name
    let folder_name = source_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| "Invalid folder name".to_string())?;

    // Create output file path in the same directory as the source folder
    let parent_dir = source_path
        .parent()
        .ok_or_else(|| "Cannot get parent directory".to_string())?;

    let archive_name = format!("{}.tar.gz", folder_name);
    let output_path = parent_dir.join(&archive_name);

    // Create the output file
    let output_file =
        File::create(&output_path).map_err(|e| format!("Failed to create output file: {}", e))?;

    // Create gzip encoder
    let gz_encoder = GzEncoder::new(output_file, Compression::default());
    let writer = BufWriter::new(gz_encoder);

    // Create tar archive builder
    let mut tar_builder = Builder::new(writer);

    // Add only the folder contents (not the root folder itself)
    let entries = std::fs::read_dir(source_path)
        .map_err(|e| format!("Failed to read directory contents: {}", e))?;

    for entry in entries {
        let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
        let entry_path = entry.path();
        let relative_path = entry_path
            .strip_prefix(source_path)
            .map_err(|e| format!("Failed to calculate relative path: {}", e))?;

        if entry_path.is_dir() {
            tar_builder
                .append_dir_all(relative_path, &entry_path)
                .map_err(|e| format!("Failed to add directory to archive: {}", e))?;
        } else {
            tar_builder
                .append_path_with_name(&entry_path, relative_path)
                .map_err(|e| format!("Failed to add file to archive: {}", e))?;
        }
    }

    // Finish writing the archive
    // into_inner() returns the BufWriter, then we need to get the GzEncoder from it
    let buf_writer = tar_builder
        .into_inner()
        .map_err(|e| format!("Failed to finalize archive: {}", e))?;

    // Get the GzEncoder from the BufWriter and finish compression
    // into_inner() on BufWriter returns Result, and we need to flush first
    let gz_encoder = buf_writer
        .into_inner()
        .map_err(|e| format!("Failed to get gzip encoder: {}", e))?;
    gz_encoder
        .finish()
        .map_err(|e| format!("Failed to finalize compression: {}", e))?;

    // Return the path to the compressed archive
    output_path
        .to_str()
        .ok_or_else(|| "Failed to convert path to string".to_string())
        .map(|s| s.to_string())
}

#[tauri::command]
async fn read_file_bytes(file_path: String) -> Result<Vec<u8>, String> {
    use std::fs;
    fs::read(&file_path).map_err(|e| format!("Failed to read file: {}", e))
}

#[tauri::command]
async fn extract_archive(archive_path: String, destination_path: String) -> Result<(), String> {
    let archive_path = Path::new(&archive_path);
    if !archive_path.exists() {
        return Err(format!(
            "Archive does not exist: {}",
            archive_path.display()
        ));
    }

    let destination_path = Path::new(&destination_path);
    std::fs::create_dir_all(destination_path)
        .map_err(|e| format!("Failed to create destination directory: {}", e))?;

    let file = File::open(archive_path).map_err(|e| format!("Failed to open archive: {}", e))?;
    let decoder = GzDecoder::new(file);
    let mut archive = Archive::new(decoder);

    archive
        .unpack(destination_path)
        .map_err(|e| format!("Failed to extract archive: {}", e))?;

    Ok(())
}

#[derive(serde::Serialize, Clone)]
struct UploadProgress {
    progress: u64,
    total: u64,
    transfer_speed: f64,
}

#[tauri::command]
async fn upload_file_as_form_data(
    url: String,
    file_path: String,
    auth_token: Option<String>,
    progress_channel: tauri::ipc::Channel<UploadProgress>,
) -> Result<(), String> {
    use std::time::Instant;

    let file_path = Path::new(&file_path);

    // Check if file exists
    if !file_path.exists() {
        return Err(format!("File does not exist: {}", file_path.display()));
    }

    // Get file metadata
    let metadata =
        std::fs::metadata(file_path).map_err(|e| format!("Failed to get file metadata: {}", e))?;
    let file_size = metadata.len();

    // Get filename
    let filename = file_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| "Invalid filename".to_string())?;

    // Open file
    let mut file = File::open(file_path).map_err(|e| format!("Failed to open file: {}", e))?;

    // Create multipart form
    let mut form = reqwest::multipart::Form::new();

    // Read file into memory (for small files) or use streaming for large files
    // For now, we'll read into memory. For very large files, consider streaming
    let mut file_data = Vec::new();
    file.read_to_end(&mut file_data)
        .map_err(|e| format!("Failed to read file: {}", e))?;

    // Create a part with the file data
    let part = reqwest::multipart::Part::bytes(file_data)
        .file_name(filename.to_string())
        .mime_str("application/gzip")
        .map_err(|e| format!("Failed to create multipart part: {}", e))?;

    // Add the part with field name "files" (as PocketBase expects)
    form = form.part("files", part);

    // Build the request
    let client = reqwest::Client::new();
    let mut request = client.patch(&url).multipart(form);

    // Add authorization header if provided
    if let Some(token) = auth_token {
        request = request.header("Authorization", format!("Bearer {}", token));
    }

    // Send request with progress tracking
    let start_time = Instant::now();
    let response = request
        .send()
        .await
        .map_err(|e| format!("Failed to send request: {}", e))?;

    // Calculate progress (we've already sent everything, but we can report completion)
    let elapsed = start_time.elapsed().as_secs_f64();
    let transfer_speed = if elapsed > 0.0 {
        file_size as f64 / elapsed
    } else {
        0.0
    };

    // Send progress update
    let _ = progress_channel.send(UploadProgress {
        progress: file_size,
        total: file_size,
        transfer_speed,
    });

    // Check response status
    if !response.status().is_success() {
        let status = response.status();
        let error_text = response
            .text()
            .await
            .unwrap_or_else(|_| "Unknown error".to_string());
        return Err(format!(
            "Upload failed with status {}: {}",
            status, error_text
        ));
    }

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_upload::init())
        .plugin(tauri_plugin_os::init())
        .setup(|app| {
            // let app_ = app.handle().clone();
            // let window =
            //     WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
            //         .on_new_window(move |url, features| {
            //             // Create a new window with a unique label
            //             let builder = tauri::WebviewWindowBuilder::new(
            //                 &app_,
            //                 "opened-window", // Ideally use a counter for multiple windows
            //                 tauri::WebviewUrl::External(url.clone()),
            //             )
            //             .window_features(features)
            //             .on_document_title_changed(|window, title| {
            //                 window.set_title(&title).unwrap();
            //             })
            //             .title(url.as_str());

            //             match builder.build() {
            //                 Ok(window) => tauri::webview::NewWindowResponse::Create { window },
            //                 Err(_) => tauri::webview::NewWindowResponse::Deny,
            //             }
            //         })
            //         .build()?;
            // window.set_min_size(Some(LogicalSize::new(800, 600)))?;
            Ok(())
        })
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            archive_and_compress_folder,
            read_file_bytes,
            extract_archive,
            upload_file_as_form_data
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
