// launcher_ui.js — JS для godot_wry интеграции

// Обработка статуса от Godot
// Используем globalThis для полной совместимости

globalThis.onLauncherStatus = function(status) {
    const playBtn = document.getElementById('playBtn');
    if (!playBtn) return;
    playBtn.disabled = true;
    let text = 'Играть';
    if (status.state === 'checking') {
        text = 'Проверка обновления...';
    } else if (status.state === 'downloading') {
        text = 'Скачивание...';
    } else if (status.state === 'no_game') {
        text = 'Скачать';
        playBtn.disabled = false;
        playBtn.dataset.action = 'download';
        playBtn.dataset.downloadUrl = status.download_url || '';
        playBtn.dataset.exeName = status.exe_name || '';
    } else if (status.state === 'outdated') {
        text = 'Обновить';
        playBtn.disabled = false;
        playBtn.dataset.action = 'download';
        playBtn.dataset.downloadUrl = status.download_url || '';
        playBtn.dataset.exeName = status.exe_name || '';
        playBtn.dataset.oldExe = status.old_exe || '';
    } else if (status.state === 'ready') {
        text = 'Играть';
        playBtn.disabled = false;
        playBtn.dataset.action = 'play';
        playBtn.dataset.exeFile = status.exe_file || '';
    } else if (status.state === 'launched') {
        text = 'Запущено';
        playBtn.disabled = true;
    } else if (status.state === 'error') {
        text = status.message || 'Ошибка';
        playBtn.disabled = false;
    }
    playBtn.innerHTML = `<span class="play-icon">▶</span> ${text}`;
};

// Обработка нажатия на кнопку "Играть"
document.addEventListener('DOMContentLoaded', function() {
    const playBtn = document.getElementById('playBtn');
    if (playBtn) {
        playBtn.addEventListener('click', function() {
            if (!globalThis.godot || !globalThis.godot.launcher_command) return;
            const action = playBtn.dataset.action || 'play';
            if (action === 'download') {
                globalThis.godot.launcher_command({
                    action: 'download',
                    download_url: playBtn.dataset.downloadUrl,
                    exe_name: playBtn.dataset.exeName,
                    old_exe: playBtn.dataset.oldExe
                });
            } else if (action === 'play') {
                globalThis.godot.launcher_command({
                    action: 'play',
                    exe_file: playBtn.dataset.exeFile
                });
            }
        });
    }
});
