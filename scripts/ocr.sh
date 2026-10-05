#!/usr/bin/env bash

img="/tmp/ocrshot.png"
txt="/tmp/ocrshot.txt"

pkill -f "$txt"

grim -g "$(slurp)" "$img"

if [ ! -s "$img" ]; then
    notify-send "OCR" "截图失败"
    exit 1
fi

text=$(tesseract "$img" stdout -l chi_sim+eng 2>/dev/null)

if [ -z "$text" ]; then
    notify-send "OCR" "未识别到文字"
    exit 1
fi

# 自动翻译成中文
translated=$(trans -brief :zh "$text" 2>/dev/null)

{
    echo "===== OCR ====="
    echo
    echo "$text"

    echo
    echo "===== 翻译 ====="
    echo
    echo "$translated"
} > "$txt"

printf "%s" "$translated" | wl-copy

notify-send "OCR 翻译完成" "翻译已复制"

mousepad "$txt"
