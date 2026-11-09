#!/bin/bash
# susfs-bakasu-compat.sh - 给 SUSFS v2.1.0 内核补齐 BakaSU 4.2 使用的新 helper
#
# BakaSU 4.2（原 ReSukiSU）在 setuid/sucompat 路径里调用：
#   susfs_set_current_proc_no_su()
#   susfs_is_current_proc_no_su()
#   susfs_clear_current_proc_no_su()
#   susfs_set_current_proc_umounted_for_zygote_next()
# 而 odin（resukisu 分支）自带的 SUSFS v2.1.0 只有：
#   susfs_set_current_proc_umounted()
#   susfs_is_current_proc_umounted()
# 语义相同（都操作 TIF_PROC_UMOUNTED）。这里在 fs/susfs.c 里补真实函数，
# 而不是只加头文件宏 —— BakaSU 的 hook/setuid_hook.c 并没有 include
# susfs_def.h，只有全局符号才能让 vmlinux 链接通过。
#
# 用法：bash scripts/susfs-bakasu-compat.sh <kernel-dir>
# 幂等：可重复运行。
set -euo pipefail

KDIR="${1:?usage: susfs-bakasu-compat.sh <kernel-dir>}"
SRC="$KDIR/fs/susfs.c"

[ -d "$KDIR" ] || { echo "ERROR: kernel dir $KDIR not found"; exit 1; }
[ -f "$SRC" ] || { echo "ERROR: $SRC not found (is this the odin SUSFS tree?)"; exit 1; }

if grep -q 'susfs_bakasu_compat' "$SRC"; then
  echo "=== [susfs-bakasu] compat helpers already present (skip) ==="
  exit 0
fi

cat >> "$SRC" <<'EOF'

/* susfs_bakasu_compat: BakaSU 4.2 uses the newer no_su / zygote_next helper
 * names, while this kernel tree ships SUSFS v2.1.0 with the umounted names.
 * Both operate on TIF_PROC_UMOUNTED.  Real symbols (not header macros) are
 * required because BakaSU's hook/setuid_hook.c calls them without including
 * susfs_def.h.
 */
#include <linux/sched.h>

void susfs_set_current_proc_no_su(void)
{
	susfs_set_current_proc_umounted();
}

bool susfs_is_current_proc_no_su(void)
{
	return susfs_is_current_proc_umounted();
}

void susfs_clear_current_proc_no_su(void)
{
	clear_thread_flag(TIF_PROC_UMOUNTED);
}

void susfs_set_current_proc_umounted_for_zygote_next(void)
{
	susfs_set_current_proc_umounted();
}
EOF

grep -n 'susfs_bakasu_compat' "$SRC"
echo "=== [susfs-bakasu] DONE ==="
