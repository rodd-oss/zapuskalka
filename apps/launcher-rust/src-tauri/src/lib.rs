use flate2::Compression;
use flate2::{read::GzDecoder, write::GzEncoder};
use serde::Serialize;
use std::collections::{HashMap, VecDeque};
use std::fs::File;
use std::io::{BufReader, BufWriter};
use std::path::Path;
use std::time::Duration;
use tar::{Archive, Builder};
use tauri::State;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    LogicalPosition, LogicalSize, Manager,
};
use tokio::process::Command;
use tokio::sync::Mutex;

use crate::rate_meter::RateMeter;
use crate::tracking_reader::TrackingReader;
use crate::tracking_tokio_stream::TrackingTokioStream;
use crate::tracking_writer::TrackingWriter;

mod models;
mod rate_meter;
mod states;
mod tracking_reader;
mod tracking_tokio_stream;
mod tracking_writer;

#[derive(Serialize)]
struct ProgressCallbackData {
    current_bytes: u64,
    total_bytes: u64,
    delta_per_second: u64,
}

// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
async fn archive_and_compress_folder(
    folder_path: String,
    progress_channel: tauri::ipc::Channel<ProgressCallbackData>,
    speed_update_interval: Option<f64>,
) -> Result<String, String> {
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

    let mut total_bytes = 0_u64;
    let mut packed_bytes = 0_u64;

    // Find all files
    let mut to_visit = VecDeque::new();
    let mut all_entries = vec![];

    to_visit.push_front(source_path.to_path_buf());

    while let Some(dir_path) = to_visit.pop_front() {
        let entries = std::fs::read_dir(dir_path)
            .map_err(|e| format!("Failed to read directory contents: {}", e))?;

        for entry in entries {
            let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
            let entry_path = entry.path();

            if entry_path.is_dir() {
                to_visit.push_front(entry_path);
            } else {
                let meta = entry
                    .metadata()
                    .map_err(|e| format!("Failed to get file metadata: {}", e))?;
                total_bytes += meta.len();
                all_entries.push(entry);
            }
        }
    }

    // Create gzip encoder
    let gz_encoder = GzEncoder::new(output_file, Compression::default());
    let writer = BufWriter::new(gz_encoder);
    let progress_channel_clone = progress_channel.clone();
    let mut packing_speed_rate = RateMeter::new(Duration::from_secs_f64(
        speed_update_interval.unwrap_or(1.0),
    ));
    let tracker = TrackingWriter::new(writer, move |buf| {
        let delta = buf.len() as u64;
        packing_speed_rate.add_value(delta);
        packed_bytes += delta;
        let res = progress_channel_clone
            .send(ProgressCallbackData {
                current_bytes: packed_bytes,
                total_bytes,
                delta_per_second: packing_speed_rate.get_rate() as u64,
            })
            .map_err(|e| format!("Failed to send packing progress info: {}", e));
        if let Err(err) = res {
            eprintln!("{}", err);
        }
    });

    // Create tar archive builder
    let mut tar_builder = Builder::new(tracker);

    progress_channel
        .send(ProgressCallbackData {
            current_bytes: 0,
            total_bytes,
            delta_per_second: 0,
        })
        .map_err(|e| format!("Failed to emit packing progress event: {}", e))?;

    for entry in all_entries {
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
    // into_inner() returns the TrackingWriter, then we need to get the BufWriter from it
    let tracker = tar_builder
        .into_inner()
        .map_err(|e| format!("Failed to finalize archive: {}", e))?;
    let buf_writer = tracker.into_inner();

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
async fn extract_archive(
    archive_path: String,
    destination_path: String,
    progress_channel: tauri::ipc::Channel<ProgressCallbackData>,
    speed_update_interval: Option<f64>,
) -> Result<(), String> {
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

    let mut read_bytes = 0_u64;
    let total_bytes = file
        .metadata()
        .map_err(|e| format!("Failed to get file metadata: {}", e))?
        .len();

    let mut extract_rate = RateMeter::new(Duration::from_secs_f64(
        speed_update_interval.unwrap_or(1.0),
    ));
    let tracker = TrackingReader::new(file, |buf| {
        let buf_len = buf.len() as u64;
        read_bytes += buf_len;
        extract_rate.add_value(buf_len);

        let res = progress_channel
            .send(ProgressCallbackData {
                current_bytes: read_bytes,
                total_bytes,
                delta_per_second: extract_rate.get_rate() as u64,
            })
            .map_err(|e| format!("Failed to emit extracting progress info: {}", e));
        if let Err(e) = res {
            eprintln!("{}", e);
        }
    });
    let decoder = GzDecoder::new(tracker);
    let mut archive = Archive::new(decoder);

    archive
        .unpack(destination_path)
        .map_err(|e| format!("Failed to extract archive: {}", e))?;

    Ok(())
}

#[tauri::command]
async fn upload_file_as_form_data(
    url: String,
    file_path: String,
    auth_token: Option<String>,
    progress_channel: tauri::ipc::Channel<ProgressCallbackData>,
    speed_update_interval: Option<f64>,
) -> Result<(), String> {
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
    let file = tokio::fs::File::open(file_path)
        .await
        .map_err(|e| format!("Failed to open file: {}", e))?;

    let file_meta = file
        .metadata()
        .await
        .map_err(|e| format!("Failed to get file metadata: {}", e))?;

    let mut read_bytes = 0_u64;
    let total_bytes = file_meta.len();

    let progress_channel_clone = progress_channel.clone();
    let mut uploading_speed_rate = RateMeter::new(Duration::from_secs_f64(
        speed_update_interval.unwrap_or(0.0),
    ));
    let tracker = TrackingTokioStream::new(file, move |read_len| {
        read_bytes += read_len;
        uploading_speed_rate.add_value(read_len);

        let res = progress_channel_clone
            .send(ProgressCallbackData {
                current_bytes: read_bytes,
                total_bytes,
                delta_per_second: uploading_speed_rate.get_rate() as u64,
            })
            .map_err(|e| format!("Failed to send update progress to channel: {}", e));
        if let Err(e) = res {
            eprintln!("{}", e);
        }
    });

    // Create multipart form
    let mut form = reqwest::multipart::Form::new();

    // Create a part with the file stream
    let part_body = reqwest::Body::wrap_stream(tracker);
    let part = reqwest::multipart::Part::stream_with_length(part_body, file_size)
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
    let response = request
        .send()
        .await
        .map_err(|e| format!("Failed to send request: {}", e))?;

    // Send progress update
    let _ = progress_channel.send(ProgressCallbackData {
        current_bytes: file_size,
        total_bytes: file_size,
        delta_per_second: 0,
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

// TODO: for now we return PID of launched program, but application can spawn actual program
//       and then terminate entrypoint program. Ideally we should track all children spawned
//       by entrypoint. When we will do that here we should return not PID, but some key
//       which can be used to query/wait when application terminated.
#[tauri::command]
async fn launch_app(
    app_id: String,
    app_data_path: State<'_, states::DataDirPath>,
    apps_running: State<'_, Mutex<states::AppsRunningStatus>>,
) -> Result<u32, String> {
    let app_data_path = &app_data_path.inner().0;
    let app_json_path = app_data_path.join(format!("apps/{}.json", app_id));

    let file =
        File::open(app_json_path).map_err(|e| format!("Failed to open app json file: {}", e))?;
    let reader = BufReader::new(file);
    let app_info = serde_json::from_reader::<_, models::InstalledAppInfo>(reader)
        .map_err(|e| format!("Failed to parse app json: {}", e))?;

    let entrypoint_path = app_info.install_dir.join(app_info.entrypoint);
    if !entrypoint_path.exists() {
        return Err("entrypoint doesn't exists".to_string());
    }

    let app_child = Command::new(entrypoint_path)
        .spawn()
        .map_err(|e| format!("Failed to spawn app process: {}", e))?;
    let pid = app_child.id().ok_or_else(|| format!("Child not started"))?;

    apps_running
        .lock()
        .await
        .app2child
        .insert(app_id, app_child);

    // TODO: wait for child close and remove it from apps_running.app2child map

    Ok(pid)
}

#[tauri::command]
async fn wait_for_app_close(
    app_id: String,
    apps_running: State<'_, Mutex<states::AppsRunningStatus>>,
) -> Result<(), String> {
    let mut apps_running = apps_running.lock().await;
    let child = if let Some(v) = apps_running.app2child.get_mut(&app_id) {
        v
    } else {
        return Ok(());
    };

    child
        .wait()
        .await
        .map_err(|e| format!("Failed to wait for child process: {}", e))?;

    Ok(())
}

#[derive(serde::Serialize, serde::Deserialize)]
struct WindowState {
    width: f64,
    height: f64,
    x: Option<f64>,
    y: Option<f64>,
}

fn get_window_state_path(app: &tauri::AppHandle) -> Result<std::path::PathBuf, String> {
    let app_config_dir = app
        .path()
        .app_config_dir()
        .map_err(|e| format!("Failed to get app config dir: {}", e))?;
    std::fs::create_dir_all(&app_config_dir)
        .map_err(|e| format!("Failed to create config dir: {}", e))?;
    Ok(app_config_dir.join("window_state.json"))
}

fn save_window_state(app: &tauri::AppHandle, window: &tauri::WebviewWindow) -> Result<(), String> {
    let scale_factor = window.scale_factor().unwrap_or(1.0);
    let size = window
        .inner_size()
        .map_err(|e| format!("Failed to get window size: {}", e))?;

    let position = window
        .inner_position()
        .ok()
        .map(|p| LogicalPosition::new(p.x as f64 / scale_factor, p.y as f64 / scale_factor));

    let state = WindowState {
        width: size.width as f64 / scale_factor,
        height: size.height as f64 / scale_factor,
        x: position.map(|p| p.x),
        y: position.map(|p| p.y),
    };

    let state_path = get_window_state_path(app)?;
    let json = serde_json::to_string_pretty(&state)
        .map_err(|e| format!("Failed to serialize window state: {}", e))?;

    std::fs::write(&state_path, json)
        .map_err(|e| format!("Failed to write window state: {}", e))?;

    Ok(())
}

fn load_window_state(app: &tauri::AppHandle) -> Result<Option<WindowState>, String> {
    let state_path = get_window_state_path(app)?;

    if !state_path.exists() {
        return Ok(None);
    }

    let json = std::fs::read_to_string(&state_path)
        .map_err(|e| format!("Failed to read window state: {}", e))?;

    serde_json::from_str(&json)
        .map(Some)
        .map_err(|e| format!("Failed to parse window state: {}", e))
}

fn should_set_webkit_workaround() -> bool {
    let is_appimage = std::env::var("APPIMAGE").is_ok();

    if !is_appimage {
        return false;
    }

    #[cfg(target_os = "linux")]
    {
        let info = os_info::get();
        let os_type = info.os_type();

        // check if it's not Debian or Ubuntu (Debian-based)
        !matches!(os_type, os_info::Type::Debian | os_info::Type::Ubuntu)
    }

    #[cfg(not(target_os = "linux"))]
    {
        false
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    if should_set_webkit_workaround() {
        unsafe {
            std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
        }
    }

    let client = sentry::init((
        "https://1487f8979fe541888367281982f24dbb@glitchtip.d.roddtech.ru/2",
        sentry::ClientOptions {
            release: sentry::release_name!(),
            auto_session_tracking: true,
            ..Default::default()
        },
    ));

    // Caution! Everything before here runs in both app and crash reporter processes
    #[cfg(not(target_os = "ios"))]
    let _guard = tauri_plugin_sentry::minidump::init(&client);
    // Everything after here runs in only the app process

    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            // Show the main window when another instance is launched
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.unminimize();
                let _ = window.show();
                let _ = window.set_focus();
            }
        }))
        .plugin(tauri_plugin_deep_link::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_upload::init())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_sentry::init_with_no_injection(&client))
        .setup(|app| {
            let app_handle = app.handle().clone();
            #[cfg(any(target_os = "linux", all(debug_assertions, windows)))]
            {
                use tauri_plugin_deep_link::DeepLinkExt;
                app_handle.deep_link().register_all()?;
            }
            let saved_state = load_window_state(app.handle()).ok().flatten();

            let window = tauri::WebviewWindowBuilder::from_config(
                app.handle(),
                &app.config().app.windows[0],
            )?
            .on_new_window({
                let app_ = app.handle().clone();
                move |url, features| {
                    let builder = tauri::WebviewWindowBuilder::new(
                        &app_,
                        "opened-window",
                        tauri::WebviewUrl::External(url.clone()),
                    )
                    .window_features(features)
                    .on_document_title_changed(|window, title| {
                        let _ = window.set_title(&title);
                    })
                    .title(url.as_str());

                    match builder.build() {
                        Ok(window) => tauri::webview::NewWindowResponse::Create { window },
                        Err(_) => tauri::webview::NewWindowResponse::Deny,
                    }
                }
            })
            .build()?;

            window.set_title("Zapuskalka")?;
            window.set_min_size(Some(LogicalSize::new(800, 600)))?;

            if let Some(state) = saved_state {
                window
                    .set_size(LogicalSize::new(state.width, state.height))
                    .map_err(|e| format!("Failed to set window size: {}", e))?;
                if let (Some(x), Some(y)) = (state.x, state.y) {
                    window
                        .set_position(LogicalPosition::new(x, y))
                        .map_err(|e| format!("Failed to set window position: {}", e))?;
                }
            } else {
                window
                    .set_size(LogicalSize::new(800, 600))
                    .map_err(|e| format!("Failed to set window size: {}", e))?;
            }

            let window_clone = window.clone();
            let app_handle_clone = app_handle.clone();
            // TODO: Save window state on resize and move with debounce
            window.on_window_event(move |event| {
                if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                    if let Err(e) = save_window_state(&app_handle_clone, &window_clone) {
                        eprintln!("Failed to save window state: {}", e);
                    }
                    api.prevent_close();
                    let _ = window_clone.hide();
                }
            });

            let app_handle_for_tray = app.handle().clone();
            let app_handle_for_menu = app.handle().clone();
            let show_i =
                MenuItem::with_id(&app_handle_for_menu, "show", "Open", true, None::<&str>)?;
            let quit_i =
                MenuItem::with_id(&app_handle_for_menu, "quit", "Quit", true, None::<&str>)?;
            let menu = Menu::with_items(&app_handle_for_menu, &[&show_i, &quit_i])?;

            let restore_window_position =
                |window: &tauri::WebviewWindow, app_handle: &tauri::AppHandle| {
                    let (x, y) = match load_window_state(app_handle) {
                        Ok(Some(state)) => (state.x.unwrap_or(0.0), state.y.unwrap_or(0.0)),
                        Ok(None) => (0.0, 0.0),
                        Err(e) => {
                            eprintln!("Failed to load window state: {}", e);
                            (0.0, 0.0)
                        }
                    };

                    if let Err(e) = window.set_position(LogicalPosition::new(x, y)) {
                        eprintln!("Failed to restore window position: {}", e);
                    }
                };

            let app_handle_for_show = app.handle().clone();
            let window_for_show = window.clone();
            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("Zapuskalka")
                .menu(&menu)
                .on_menu_event(move |_app, event| match event.id.as_ref() {
                    "show" => {
                        restore_window_position(&window_for_show, &app_handle_for_show);
                        let _ = window_for_show.show();
                        let _ = window_for_show.set_focus();
                    }
                    "quit" => {
                        app_handle_for_tray.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event({
                    let app_handle_for_click = app.handle().clone();
                    let app_handle_for_save = app.handle().clone();
                    move |tray, event| {
                        if let TrayIconEvent::Click {
                            button: MouseButton::Left,
                            button_state: MouseButtonState::Up,
                            ..
                        } = event
                        {
                            let app = tray.app_handle();
                            if let Some(window) = app.get_webview_window("main") {
                                if window.is_visible().unwrap_or(false) {
                                    let _ = save_window_state(&app_handle_for_save, &window);
                                    let _ = window.hide();
                                } else {
                                    restore_window_position(&window, &app_handle_for_click);
                                    let _ = window.unminimize();
                                    let _ = window.show();
                                    let _ = window.set_focus();
                                }
                            }
                        }
                    }
                })
                .build(app)
                .map_err(|e| format!("Failed to create tray icon: {}", e))?;

            app.manage(states::DataDirPath(app.path().app_data_dir()?));
            app.manage(Mutex::new(states::AppsRunningStatus {
                app2child: HashMap::new(),
            }));

            Ok(())
        })
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            archive_and_compress_folder,
            read_file_bytes,
            extract_archive,
            upload_file_as_form_data,
            launch_app,
            wait_for_app_close,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
