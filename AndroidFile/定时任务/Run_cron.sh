#!/system/bin/sh

CN_AMPM() {
  case $1 in
    1|3|4|5)  alias $2="凌晨"  ;;
    6|7|8|9)  alias $2="早上"  ;;
    10|11)  alias $2="上午"  ;;
    12)  alias $2="中午"  ;;
    13|14|15|16|17)  alias $2="下午"  ;;
    18|19|20|21|22|23|0)  alias $2="晚上"  ;;
  esac
}

# === 通用路径定义 - 兼容 Magisk / KernelSU / APatch / FolkPatch ===
MODID="crond_clear_the_blacklist"
MODPATH="/data/adb/modules/$MODID"          # APatch/FolkPatch 标准路径

# 如果是 KSU 风格 fork，可能用 /data/adb/ksu/modules，但 FolkPatch 通常认 modules
[ -d "/data/adb/ksu/modules/$MODID" ] && MODPATH="/data/adb/ksu/modules/$MODID"
[ -d "/data/adb/ap/modules/$MODID" ] && MODPATH="/data/adb/ap/modules/$MODID"  # 少数 fork 用这个

mod_bin_path="$MODPATH/bin"
[ ! -d "$mod_bin_path" ] && { echo "错误: $mod_bin_path 不存在"; exit 88; }

set_path="${0%/*}"
set_file="$set_path/定时设置.ini"
cron_d_path="$MODPATH/script/set_cron.d"
[ ! -d "$cron_d_path" ] && mkdir -p "$cron_d_path"

. "$MODPATH/script/clear_the_blacklist_functions.sh" 2>/dev/null || { echo "缺少 clear_the_blacklist_functions.sh"; exit 99; }

if [ -f "$set_file" ]; then
  . "$set_file"
  [ $? -ne 0 ] && { echo "- [!]: 文件读取异常，请检查 $set_file"; exit 1; }
else
  echo "- [!]: 缺少 $set_file 文件"; exit 2
fi

# 验证 minute（保持原样，但简化）
if [[ "$minute" =~ ^[1-9][0-9]*$ && "$minute" -le 60 && "$minute" -ge 1 ]]; then
  echo "- 填写正确 | minute=\"$minute\""
else
  echo "- [!]: minute 错误，必须是 1-60 的整数"; exit 3
fi

case "$what_time_run" in
  y|n) echo "- 填写正确 | what_time_run=\"$what_time_run\"" ;;
  *) echo "- [!]: what_time_run 必须是 y 或 n"; exit 5 ;;
esac

if [ "$what_time_run" = "y" ]; then
  what_time_1=$(echo "$what_time" | awk -F "-" '{print $1}')
  what_time_2=$(echo "$what_time" | awk -F "-" '{print $2}')

  # 简化验证（原版太啰嗦，但保留核心）
  if [[ -z "$what_time_1" || -z "$what_time_2" || ! "$what_time_1" =~ ^[0-9]+$ || ! "$what_time_2" =~ ^[0-9]+$ || "$what_time_1" -ge 24 || "$what_time_2" -ge 24 || "$what_time_1" == "$what_time_2" ]]; then
    echo "- [!]: what_time 格式错误，应为 几点-几点（如 9-22），0-23 范围且不相等"
    exit 6
  fi

  [ "$what_time_1" -gt "$what_time_2" ] && cn_text="第二天" || cn_text=""
  [ "$what_time_2" = "0" ] && cn_text=""
  CN_AMPM "$what_time_1" "time_period_1"
  CN_AMPM "$what_time_2" "time_period_2"

  logd_ini="minute=\"$minute\" | what_time_run=\"$what_time_run\" | what_time=\"$what_time\""
  crond_rule="*/$minute $what_time * * *"
  print_set="每天${time_period_1}${what_time_1}:00到${cn_text}${time_period_2}${what_time_2}:59，每隔${minute}分钟运行一次。"
else
  logd_ini="minute=\"$minute\" | what_time_run=\"$what_time_run\""
  crond_rule="*/$minute * * * *"
  print_set="24H 每隔${minute}分钟运行一次"
fi

echo "- 定时设置 | $crond_rule"
echo "- 内容解读 | $print_set"
echo "$print_set" > "$MODPATH/print_set"

# 杀死旧 crond（更通用方式）
clear_the_blacklist_crond_pid=$(ps -ef | grep -v grep | grep -E 'crond.*crond_clear_the_blacklist' | awk '{print $2}')
[ -n "$clear_the_blacklist_crond_pid" ] && {
  echo "- 杀死旧定时 | pid: $clear_the_blacklist_crond_pid"
  kill -9 "$clear_the_blacklist_crond_pid" 2>/dev/null
}

# === 兼容 busybox/crond ===
if [ -f "/data/adb/ap/bin/busybox" ]; then
  # FolkPatch / APatch 常见路径
  BUSYBOX="/data/adb/ap/bin/busybox"
elif [ -f "/data/adb/ksu/bin/busybox" ]; then
  BUSYBOX="/data/adb/ksu/bin/busybox"
else
  # Magisk 回退
  MAGISKTMP=$(magisk --path 2>/dev/null || echo "/sbin")
  BUSYBOX="$MAGISKTMP/.magisk/busybox"
fi

alias crond="$BUSYBOX crond"
alias bash="$mod_bin_path/bash"   # 假设模块有自带 bash，否则改成 /system/bin/bash

chmod -R 0777 "$MODPATH" 2>/dev/null

# 写 crontab
echo "# set cron $(date '+%m/%d %T')" > "$cron_d_path/root"
echo "SHELL=$mod_bin_path/bash" >> "$cron_d_path/root"   # 或改成 SHELL=/system/bin/sh 如果 bash 问题
echo "$crond_rule $mod_bin_path/bash \"$MODPATH/script/Run_clear.sh\"" >> "$cron_d_path/root"

# 启动 crond
crond -c "$cron_d_path" && {
  new_pid=$(ps -ef | grep -v grep | grep -E 'crond.*crond_clear_the_blacklist' | awk '{print $2}')
  echo "- 定时启动成功 | pid: $new_pid"
  # log_md_set_cron_clear 假设是函数，保留
  log_md_set_cron_clear 2>/dev/null
  [ -f "$MODPATH/script/Run_clear.sh" ] && sh "$MODPATH/script/Run_clear.sh" >/dev/null 2>&1 || echo "- 模块脚本缺失！"
} || echo "- crond 启动失败！检查 busybox 路径或权限"

exit 0
