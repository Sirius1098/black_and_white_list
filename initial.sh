#!/system/bin/sh
MODDIR=${0%/*}
. $MODDIR/script/clear_the_blacklist_functions.sh

# === KernelSU / APatch / Magisk 通用 busybox 兼容 ===
if [ -n "$KSU" ]; then
    # KernelSU
    BUSYBOX="/data/adb/ksu/bin/busybox"
    alias crond="$BUSYBOX crond"
elif [ -f "/data/adb/ap/bin/busybox" ]; then
    # APatch
    BUSYBOX="/data/adb/ap/bin/busybox"
    alias crond="$BUSYBOX crond"
else
    # Magisk（保持原样）
    MAGISK_TMP=$(magisk --path 2>/dev/null)
    [[ -z $MAGISK_TMP ]] && MAGISK_TMP="/sbin"
    alias crond="$MAGISK_TMP/.magisk/busybox/crond"
fi
#alias bash="$MODDIR/bin/bash"
chmod -R 0777 $MODDIR
chmod -R 0777 $black_and_white_list_path
logd "初始化完成: [initial.sh]"

if [[ -f $MODDIR/script/set_cron.d/root ]]; then
  [[ -f $MODDIR/script/cron.d/root ]] && rm -rf $MODDIR/script/cron.d/root
  crond -c $MODDIR/script/set_cron.d
  crond_root_file=$MODDIR/script/set_cron.d/root
else
  echo "默认: 24H 每隔1分钟运行一次" > $MODDIR/print_set
  echo "SHELL=$MODDIR/bin/bash" > $MODDIR/script/cron.d/root
  echo "*/1 * * * * $MODDIR/bin/bash \"$MODDIR/script/Run_clear.sh\"" >> $MODDIR/script/cron.d/root
  crond -c $MODDIR/script/cron.d
  crond_root_file=$MODDIR/script/cron.d/root
fi

sleep 1

if [[ $(pgrep -f "crond_clear_the_blacklist/script/cron.d" | grep -v grep | wc -l) -ge 1 ]]; then
  basic_Information
  logd "$(cat $MODDIR/print_set)"
  logd "开始运行: [$crond_root_file]"
  logd "------------------------------------------------------------"
elif [[ $(pgrep -f "crond_clear_the_blacklist/script/set_cron.d" | grep -v grep | wc -l) -ge 1 ]]; then
  basic_Information
  logd "$(cat $MODDIR/print_set)"
  logd "开始运行: [$crond_root_file]"
  logd "------------------------------------------------------------"
else
  basic_Information
  logd "运行失败！"
  exit 1
fi

sh $MODDIR/script/Run_clear.sh
