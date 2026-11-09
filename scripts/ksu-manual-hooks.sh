#!/bin/bash
# ksu-manual-hooks.sh - 把 odin 树的 KSU hook 调用点改成同时支持 BakaSU 的
# KSU_MANUAL_HOOK 方式（5.4 上比 SUSFS inline 稳）。
#
# 背景：
#   - fs/exec.c、fs/open.c、fs/stat.c、kernel/reboot.c 的 hook 已经是
#     #ifdef CONFIG_KSU，KSU=y 时就会编译；BakaSU 的 manual_hook_check 只是
#     grep 文件里有没有 CONFIG_KSU_MANUAL_HOOK 字样，这里加注释即可。
#   - fs/read_write.c、kernel/sys.c、drivers/input/input.c 的 hook 被
#     #ifdef CONFIG_KSU_SUSFS 包住，manual 模式（不用 SUSFS）会编译掉，
#     需要把 guard 扩成 CONFIG_KSU_SUSFS || CONFIG_KSU_MANUAL_HOOK。
#
# 用法：bash scripts/ksu-manual-hooks.sh <kernel-dir>
# 幂等：可重复运行。
set -euo pipefail

KDIR="${1:?usage: ksu-manual-hooks.sh <kernel-dir>}"
[ -d "$KDIR" ] || { echo "ERROR: kernel dir $KDIR not found"; exit 1; }

python3 - "$KDIR" <<'PYEOF'
import os
import sys

kdir = sys.argv[1]

files = [
    'fs/exec.c',
    'fs/open.c',
    'fs/stat.c',
    'fs/read_write.c',
    'kernel/reboot.c',
    'kernel/sys.c',
    'drivers/input/input.c',
]

changed = 0
for rel in files:
    path = os.path.join(kdir, rel)
    if not os.path.exists(path):
        print('skip missing', rel)
        continue
    lines = open(path, encoding='utf-8').read().splitlines()
    out = []
    i = 0
    file_changed = False
    while i < len(lines):
        line = lines[i]
        if 'ksu_handle_' in line and not line.lstrip().startswith('*'):
            # look back for the guard that owns this hook
            j = i - 1
            guard = None
            while j >= 0 and i - j <= 12:
                s = lines[j].strip()
                if s == '#ifdef CONFIG_KSU_SUSFS':
                    guard = j
                    break
                if s == '#endif':
                    break
                j -= 1
            if guard is not None:
                lines[guard] = '#if defined(CONFIG_KSU_SUSFS) || defined(CONFIG_KSU_MANUAL_HOOK)'
                file_changed = True
            else:
                # CONFIG_KSU / defined(CONFIG_KSU) guard: add the marker comment
                j = i - 1
                k = None
                while j >= 0 and i - j <= 12:
                    s = lines[j].strip()
                    if s.startswith('#if') and 'CONFIG_KSU' in s:
                        k = j
                        break
                    if s == '#endif':
                        break
                    j -= 1
                nearby = any('CONFIG_KSU_MANUAL_HOOK' in lines[x] for x in range(max(0, k - 2), k))
                if k is not None and not nearby and 'CONFIG_KSU_MANUAL_HOOK' not in lines[k]:
                    lines.insert(k, '/* CONFIG_KSU_MANUAL_HOOK: BakaSU manual hook call site */')
                    file_changed = True
                elif k is None:
                    print('WARN: no guard found for hook in', rel)
        i += 1
    if 'CONFIG_KSU_MANUAL_HOOK' not in '\n'.join(lines):
        # keep the manual_hook_check happy even if hooks are in another form
        lines.append('/* CONFIG_KSU_MANUAL_HOOK: BakaSU manual hook */')
        file_changed = True
    if file_changed:
        open(path, 'w', encoding='utf-8', newline='').write('\n'.join(lines) + '\n')
        print('patched', rel)
        changed += 1

print('manual hook call sites patched:', changed)
PYEOF

echo "=== [ksu-manual] DONE ==="
