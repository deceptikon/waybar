# Vertical Placement — Task Checklist

- [x] Read plan document
- [x] Read current config-vertical, modules-controls.json, vertical.css
- [x] config-vertical: update modules-center (ppd, ext-display, idle_inhibitor after lang; remove tray, ollama, llama)
- [x] config-vertical: update modules-right (add ollama, llama at top; remove idle_inhibitor, ext-display)
- [x] config-vertical: remove dead inline `clock` definition + tray definition
- [x] modules-controls.json: enhance custom/ollama exec to show model names
- [x] vertical.css: update .modules-center from transparent → visible background
- [x] vertical.css: move ollama/llama into VR compact buttons section (font-size 15px)
- [x] vertical.css: add .on/.off state selectors for ollama/llama in VR section
- [x] vertical.css: remove `#tray` styles
- [x] Test with scripts/waybar-start.sh reload ✅
