// Volume slider functionality
const volumeSlider = document.getElementById("volumeSlider")
const volumeValue = document.getElementById("volumeValue")

volumeSlider.addEventListener("input", (e) => {
  volumeValue.textContent = `${e.target.value}%`
})

// Community button - opens Telegram channel
const communityBtn = document.getElementById("communityBtn")
communityBtn.addEventListener("click", () => {
  window.open("https://t.me/milanrodd", "_blank")
})

// Settings button
const settingsBtn = document.getElementById("settingsBtn")
settingsBtn.addEventListener("click", () => {
  alert("Панель настроек открыта")
})

// Play/Download/Update button logic
const playBtn = document.getElementById("playBtn")
const GAME_EXE_NAME = "gigabah.exe";
const VERSION_FILE = "last_version.txt";
const GITHUB_API_LATEST = "https://api.github.com/repos/rodd-oss/gigabah/releases/latest";
let currentVersion = null;
let latestVersion = null;
let gameExists = false;

// --- Bridge stubs (replace with real godot_wry bridge) ---
const godotBridge = {
  async readDir() {
    // Returns array of file names in launcher dir
    if (globalThis.godot && globalThis.godot.readDir) return await globalThis.godot.readDir();
    return [];
  },
  async readFile(name) {
    if (globalThis.godot && globalThis.godot.readFile) return await globalThis.godot.readFile(name);
    return null;
  },
  async writeFile(name, content) {
    if (globalThis.godot && globalThis.godot.writeFile) return await globalThis.godot.writeFile(name, content);
  },
  async downloadFile(url, name, onProgress) {
    if (globalThis.godot && globalThis.godot.downloadFile) return await globalThis.godot.downloadFile(url, name, onProgress);
    // fallback: browser download (for dev only)
    const a = document.createElement('a');
    a.href = url; a.download = name; a.click();
  },
  async runFile(name) {
    if (globalThis.godot && globalThis.godot.runFile) return await globalThis.godot.runFile(name);
    alert("[DEV] Запуск: " + name);
  }
};

function godotLog(msg) {
  if (typeof godot !== 'undefined' && typeof godot.send === 'function') {
    godot.send('godot_log', msg);
  } else {
    console.log('[Launcher]', msg);
  }
}

async function checkGameState() {
  playBtn.disabled = true;
  playBtn.innerHTML = '<span class="play-icon">⏳</span> Проверка версии';
  godotLog('Проверка наличия exe и версии...');
  // 1. Проверяем наличие exe
  const files = await godotBridge.readDir();
  godotLog('Файлы в папке: ' + JSON.stringify(files));
  gameExists = files.includes(GAME_EXE_NAME);
  godotLog(`gigabah.exe найден: ${gameExists}`);
  // 2. Читаем локальную версию
  currentVersion = null;
  if (files.includes(VERSION_FILE)) {
    try {
      currentVersion = (await godotBridge.readFile(VERSION_FILE)).trim();
      godotLog('Локальная версия: ' + currentVersion);
    } catch (e) {
      godotLog('Ошибка чтения last_version.txt: ' + e);
    }
  } else {
    godotLog('last_version.txt не найден');
  }
  // 3. Получаем последнюю версию с GitHub
  let releaseInfo;
  try {
    const resp = await fetch(GITHUB_API_LATEST);
    releaseInfo = await resp.json();
    latestVersion = releaseInfo.tag_name;
    godotLog('Последний релиз GitHub: ' + latestVersion);
  } catch (e) {
    playBtn.innerHTML = '<span class="play-icon">⚠️</span> Ошибка сети';
    godotLog('Ошибка запроса к GitHub: ' + e);
    return;
  }
  // 4. Ищем .exe в релизе
  const asset = (releaseInfo.assets||[]).find(a => a.name.endsWith('.exe'));
  if (!asset) {
    playBtn.innerHTML = '<span class="play-icon">⚠️</span> Нет файла игры';
    godotLog('.exe не найден в релизе');
    return;
  }
  godotLog('.exe для скачивания: ' + asset.browser_download_url);
  // 5. Определяем состояние
  if (!gameExists) {
    playBtn.innerHTML = '<span class="play-icon">⬇️</span> Скачать';
    playBtn.disabled = false;
    playBtn.onclick = () => downloadGame(asset.browser_download_url);
    godotLog('Статус: нет exe, предлагаем скачать');
  } else if (currentVersion !== latestVersion) {
    playBtn.innerHTML = '<span class="play-icon">🔄</span> Обновить';
    playBtn.disabled = false;
    playBtn.onclick = () => downloadGame(asset.browser_download_url);
    godotLog('Статус: exe устарел, предлагаем обновить');
  } else {
    playBtn.innerHTML = '<span class="play-icon">▶</span> Играть';
    playBtn.disabled = false;
    playBtn.onclick = () => launchGame();
    godotLog('Статус: exe актуален, можно играть');
  }
}

async function downloadGame(url) {
  playBtn.disabled = true;
  playBtn.innerHTML = '<span class="play-icon">⬇️</span> Загрузка...';
  godotLog('Начинаем скачивание .exe: ' + url);
  try {
    await godotBridge.downloadFile(url, GAME_EXE_NAME, (progress) => {
      playBtn.innerHTML = `<span class='play-icon'>⬇️</span> Загрузка... ${progress}%`;
      godotLog(`Прогресс загрузки: ${progress}%`);
    });
    await godotBridge.writeFile(VERSION_FILE, latestVersion);
    godotLog('Скачивание завершено, версия обновлена: ' + latestVersion);
    playBtn.innerHTML = '<span class="play-icon">▶</span> Играть';
    playBtn.disabled = false;
    playBtn.onclick = () => launchGame();
  } catch (e) {
    playBtn.innerHTML = '<span class="play-icon">⚠️</span> Ошибка загрузки';
    godotLog('Ошибка скачивания: ' + e);
  }
}

function launchGame() {
  playBtn.disabled = true;
  playBtn.innerHTML = '<span class="play-icon">⏳</span> Запуск...';
  godotLog('Запуск exe: ' + GAME_EXE_NAME);
  godotBridge.runFile(GAME_EXE_NAME).finally(() => {
    playBtn.innerHTML = '<span class="play-icon">▶</span> Играть';
    playBtn.disabled = false;
    godotLog('Запуск завершён');
  });
}

// Инициализация бизнес-логики (только для Windows)
globalThis.addEventListener('DOMContentLoaded', checkGameState);

// Save settings on change
const graphicsQuality = document.getElementById("graphicsQuality")
const resolution = document.getElementById("resolution")
const fullscreen = document.getElementById("fullscreen")
const vsync = document.getElementById("vsync")

function saveSettings() {
  const settings = {
    graphics: graphicsQuality.value,
    resolution: resolution.value,
    volume: volumeSlider.value,
    fullscreen: fullscreen.checked,
    vsync: vsync.checked,
  }

  localStorage.setItem("gameSettings", JSON.stringify(settings))
}

graphicsQuality.addEventListener("change", saveSettings)
resolution.addEventListener("change", saveSettings)
volumeSlider.addEventListener("change", saveSettings)
fullscreen.addEventListener("change", saveSettings)
vsync.addEventListener("change", saveSettings)

// Load settings on startup
function loadSettings() {
  const savedSettings = localStorage.getItem("gameSettings")
  if (savedSettings) {
    const settings = JSON.parse(savedSettings)
    graphicsQuality.value = settings.graphics || "high"
    resolution.value = settings.resolution || "1920x1080"
    volumeSlider.value = settings.volume || 75
    volumeValue.textContent = `${settings.volume || 75}%`
    fullscreen.checked = settings.fullscreen !== false
    vsync.checked = settings.vsync !== false
  }
}

// Simulate server status check
function checkServerStatus() {
  const serverStatus = document.getElementById("serverStatus")
  const versionStatus = document.getElementById("versionStatus")

  // Simulate API call
  setTimeout(() => {
    const isOnline = Math.random() > 0.1 // 90% chance online
    const isUpdated = Math.random() > 0.2 // 80% chance updated

    if (isOnline) {
      serverStatus.innerHTML = '<span class="status-dot online"></span> Онлайн'
    } else {
      serverStatus.innerHTML =
        '<span class="status-dot" style="background: #ef4444; box-shadow: 0 0 8px rgba(239, 68, 68, 0.6);"></span> Оффлайн'
    }

    if (isUpdated) {
      versionStatus.innerHTML = '<span class="status-dot updated"></span> Актуальна'
    } else {
      versionStatus.innerHTML =
        '<span class="status-dot" style="background: #f59e0b; box-shadow: 0 0 8px rgba(245, 158, 11, 0.6);"></span> Доступно обновление'
    }
  }, 500)
}

// Initialize
loadSettings()
checkServerStatus()

// Check server status every 30 seconds
setInterval(checkServerStatus, 30000)
