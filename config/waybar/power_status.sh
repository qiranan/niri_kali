#!/bin/bash

# --- 1. 状态切换逻辑 (用于左键点击) ---
if [ "$1" = "next" ]; then
    current=$(powerprofilesctl get)
    case $current in
        power-saver) powerprofilesctl set balanced ;;
        balanced)    powerprofilesctl set performance ;;
        performance) powerprofilesctl set power-saver ;;
        *)           powerprofilesctl set balanced ;;
    esac
    pkill -RTMIN+1 waybar
    exit 0
fi

# --- 2. 数据获取 ---
# 自动寻找电池路径
BAT_PATH=$(ls -d /sys/class/power_supply/BAT* | head -n 1)
capacity=$(cat "$BAT_PATH/capacity")
status=$(cat "$BAT_PATH/status")
profile=$(powerprofilesctl get)

# --- 3. 图标定义 (Lucide 风格 Nerd Font 字符) ---

# 电源模式图标
case $profile in
    performance) p_icon="<span color='#dc143c'>󰓅</span>" ;; # 性能模式 - 亮红色
    balanced)    p_icon="<span color='#8be9fd'>󰾅</span>" ;; # 平衡模式 - 亮青色
    power-saver) p_icon="<span color='#50fa7b'>󰾆</span>" ;; # 省电模式 - 亮绿色
    *)           p_icon="<span color='#ffffff'>󰐊</span>" ;;
esac

# 电池电量图标 (根据百分比和状态)
if [ "$status" != "Discharging" ]; then
    # 充电中 (对应你的 battery-charging SVG)
    b_icon="󰂄"
else
    # 根据百分比切换图标 (对应 Full, Medium, Low SVG)
    if [ "$capacity" -ge 80 ]; then
        b_icon="󰁹" # Full
    elif [ "$capacity" -ge 40 ]; then
        b_icon="󰁾" # Medium
    elif [ "$capacity" -ge 15 ]; then
        b_icon="󰁻" # Low
    else
        b_icon="󰂃" # Critical
    fi
fi

if [ "$status" != "Discharging" ]; then
    b_color="#50fa7b"
else
    if [ "$capacity" -ge 80 ]; then
        b_color="#50fa7b"
    elif [ "$capacity" -ge 40 ]; then
        b_color="#FEFFF7"
    elif [ "$capacity" -ge 20 ]; then
        b_color="#FCFFE6"
    else
        b_color="#F50000"
    fi
fi


if [ "$capacity" -ge 80 ]; then
    bat_class="high"
elif [ "$capacity" -ge 40 ]; then
    bat_class="medium"
elif [ "$capacity" -ge 20 ]; then
    bat_class="low"
else
    bat_class="critical"
fi

# --- 4. 输出 JSON ---
echo "{\"text\": \"$p_icon <span color='$b_color'> $capacity% $b_icon</span>\", \"alt\": \"$profile\", \"tooltip\": \"模式: $profile\n状态: $status\n电量: $capacity%\", \"class\": \"$bat_class\"}"
