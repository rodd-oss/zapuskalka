# Новый визуал лаунчера

Этот файл описывает автогенерацию сцены `MainLauncher.tscn`, близкой к прототипу (v0 TSX дизайн), без вмешательства в старую `Launcher.tscn`.

## Что создано

- Скрипт `scripts/build_main_launcher_scene.gd` — одноразовый (можно запускать повторно) конструктор, который:
  - Создаёт дерево UI (sidebar, header с фоном, теги, кнопки, прогресс).
  - Добавляет блок новостей, шаблон карточки, changelog.
  - Подготавливает скрытую панель настроек.
  - Создаёт/пересохраняет тему `themes/launcher_theme.tres` (стили кнопок, панелей, progress bar, цвета текста).
- Скрипт логики `scripts/main_launcher.gd` подключён к корню автоматически.

## Как сгенерировать / обновить

1. Открой проект в Godot.
2. Создай временную пустую сцену (Node) и прикрепи к корню `scripts/build_main_launcher_scene.gd`.
3. Запусти (F5). В Output появятся сообщения `[Builder] ...`. Будут сохранены:
   - `scenes/MainLauncher.tscn`
   - `themes/launcher_theme.tres`
4. Установи `scenes/MainLauncher.tscn` как Main Scene: Project -> Project Settings -> Run.
5. Запусти снова — откроется новый UI.

Повторный запуск билдера перезапишет сцену и тему (безопасно, но потеряешь ручные правки). Если внёс изменения вручную — удали или переименуй билдер.

## Структура ключевых узлов

```
MainLauncher (Control, script: main_launcher.gd)
└─ ContentHBox (HBoxContainer)
   ├─ Sidebar (PanelContainer)
   │  └─ VBoxContainer
   │     ├─ HomeButton / NewsButton / SettingsButton / CommunityButton / AchievementsButton / ModsButton
   │     └─ UserProfile (HBoxContainer)
   └─ MainArea (VBoxContainer)
      ├─ GameHeader (PanelContainer)
      │  ├─ BackgroundImage (TextureRect)
      │  ├─ GradientOverlay (ColorRect)
      │  └─ OverlayVBox (MarginContainer -> VBoxContainer)
      │     ├─ TagsHBox (OpenSourceTag, EngineTag)
      │     ├─ GameTitle / GameDescription
      │     ├─ ActionsHBox (PlayButton, UpdateButton, ProgressBar)
      │     ├─ VersionInfoHBox (CurrentVersionLabel, LastPlayedLabel)
      │     └─ StatusLabel
      ├─ NewsPanel (ScrollContainer)
      │  └─ VBoxContainer
      │     ├─ ChangelogRichText
      │     └─ NewsGrid (GridContainer -> NewsCardTemplate)
      └─ SettingsPanel (Control, hidden)
```

## Кастомизация

| Элемент | Где менять |
|---------|------------|
| Фоновая картинка | Список `BG_IMAGE_CANDIDATES` в `build_main_launcher_scene.gd` |
| Цвета/стили | `themes/launcher_theme.tres` (или правь код `_build_theme()`) |
| Размеры отступов header | MarginContainer `OverlayVBox` (константы margin_*) |
| Теги | Узлы `OpenSourceTag`, `EngineTag` (или текст в `main_launcher.gd`) |
| Новости (заглушки) | Массив `_seed_news_data()` в `main_launcher.gd` |
| Логика обновления | `update_manager.gd` |

## Добавление реальных новостей

1. Добавь в проект `HTTPRequest` (можно динамически) и запроси JSON с сервера.
2. Парси массив статей `{ title, excerpt, likes, comments, age }`.
3. Присвой в `_news_data` и вызови `_rebuild_news_cards()`.

## Безопасно ли удалять старую сцену?

Да, когда полностью перейдёшь на новую. Пока рекомендуется держать старую `Launcher.tscn` как fallback. Она больше не запускается, потому что в `project.godot` установлена `MainLauncher.tscn`, а автозагрузчик `LauncherBootstrap` гарантирует её генерацию при первом запуске.

## Возможные следующие шаги

- Реалистичная конверсия markdown → расширенный BBCode (заголовки, списки, ссылки).
- Темные / светлые темы (две Theme ресурса, переключение через SettingsPanel).
- Реальные настройки (fullscreen, язык, звук) с сохранением в `ConfigFile`.
- Анимация появления карточек новостей (Tween).
- Кнопка «Открыть папку игры» (OS.shell_open(...)).

---
Автогенерация сделана, чтобы не тратить время на ручное собирательство. Если потребуется частичное редактирование — можешь вручную корректировать `MainLauncher.tscn` и больше не запускать билдер.
