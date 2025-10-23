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

// Play button
const playBtn = document.getElementById("playBtn")
playBtn.addEventListener("click", () => {
  playBtn.innerHTML = '<span class="play-icon">⏳</span> Запуск...'
  playBtn.disabled = true

  // Simulate game launch
  setTimeout(() => {
    playBtn.innerHTML = '<span class="play-icon">▶</span> Играть'
    playBtn.disabled = false
    alert("Игра запущена!")
  }, 2000)
})

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
