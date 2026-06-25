#!/usr/bin/env bash
# Anchor-based injection of NoMount v1.1.0 VFS hooks into a GKI kernel tree.
# Designed to coexist with SUSFS + ReSukiSU: uses function-scoped perl substitutions
# anchored on original kernel lines that SUSFS inserts *after* (not replaces), so the
# anchors survive prior SUSFS patching. Idempotent (per-file grep guards).
#
# Usage: inject-nomount.sh <SRC_DIR containing nomount.c and nomount.h>
# Run from the kernel source root (the dir that contains fs/).
set -u
SRC="${1:?usage: inject-nomount.sh <src_dir>}"
fail=0

echo "=== NoMount VFS injection (src=$SRC) ==="

# --- 1. source files ------------------------------------------------------
cp "$SRC/nomount.c" fs/nomount.c
cp "$SRC/nomount.h" fs/nomount.h
echo "  + fs/nomount.c, fs/nomount.h"

# --- 2. Kconfig + Makefile ------------------------------------------------
if ! grep -q 'config NOMOUNT' fs/Kconfig; then
  # default y, and we deliberately do NOT add CONFIG_NOMOUNT=y to gki_defconfig: a
  # symbol left at its Kconfig default is omitted by `make savedefconfig`, so the
  # defconfig stays canonical and kleaf's "savedefconfig does not match gki_defconfig"
  # check passes. This Kconfig entry only exists when add_nomount=true (the step that
  # runs this script), so default y == enabled exactly when NoMount is injected.
  printf '\nconfig NOMOUNT\n\tbool "NoMount Path Redirection Subsystem"\n\tdefault y\n\thelp\n\t  NoMount allows path redirection and virtual file injection without mounting.\n' >> fs/Kconfig
fi
grep -q 'CONFIG_NOMOUNT' fs/Makefile || printf 'obj-$(CONFIG_NOMOUNT) += nomount.o\n' >> fs/Makefile
echo "  + Kconfig, Makefile"

# --- 3. fs/d_path.c (d_path) ----------------------------------------------
if ! grep -q 'nomount_handle_dpath' fs/d_path.c; then
  perl -0777 -pi -e 's/(\nchar \*d_path\(const struct path \*path, char \*buf, int buflen\)\n)/\n#ifdef CONFIG_NOMOUNT\nextern char *nomount_handle_dpath(const struct path *path, char *buf, int buflen);\n#endif\n$1/' fs/d_path.c
  # 5.x: d_path declares `int error;`. Bound with [^}]*? so the match cannot cross the
  # function's closing brace (6.12 d_path has NO `int error;`, so a plain .*? would run
  # into SYSCALL_DEFINE2(getcwd) and inject there — undeclared path/buflen).
  perl -0777 -pi -e 's/(char \*d_path\(const struct path \*path, char \*buf, int buflen\)\n\{\n[^}]*?\tint error;\n)/$1#ifdef CONFIG_NOMOUNT\n\tchar *nm_path = nomount_handle_dpath(path, buf, buflen);\n\tif (unlikely(nm_path)) {\n\t\treturn nm_path;\n\t}\n#endif\n/s' fs/d_path.c
  # 6.12: d_path was refactored to DECLARE_BUFFER(...) + struct path root; (no int error).
  perl -0777 -pi -e 's/(char \*d_path\(const struct path \*path, char \*buf, int buflen\)\n\{\n\tDECLARE_BUFFER\(b, buf, buflen\);\n\tstruct path root;\n)/$1#ifdef CONFIG_NOMOUNT\n\tchar *nm_path = nomount_handle_dpath(path, buf, buflen);\n\tif (unlikely(nm_path)) {\n\t\treturn nm_path;\n\t}\n#endif\n/s' fs/d_path.c
  echo "  + d_path.c"
fi

# --- 4. fs/namei.c (getname x2, generic_permission, inode_permission) -----
if ! grep -q 'nomount_handle_getname' fs/namei.c; then
  perl -0777 -pi -e 's/(#define EMBEDDED_NAME_MAX\t\(PATH_MAX - offsetof\(struct filename, iname\)\)\n)/$1#ifdef CONFIG_NOMOUNT\nextern struct filename *nomount_handle_getname(struct filename *name);\nextern int nomount_handle_permission(struct inode *inode, int mask);\n#endif\n/' fs/namei.c
  perl -0777 -pi -e 's/(\n)(\taudit_getname\(result\);)/$1#ifdef CONFIG_NOMOUNT\n\tif (!IS_ERR(result)) {\n\t\tresult = nomount_handle_getname(result);\n\t}\n#endif\n$2/g' fs/namei.c
  # generic_permission/inode_permission gained a leading mnt_idmap/mnt_userns arg in 6.x
  # and the signature may span two lines, so match the whole arg list with .*? (dotall).
  perl -0777 -pi -e 's/(int generic_permission\(.*?\)\n\{\n\tint ret;\n)/$1#ifdef CONFIG_NOMOUNT\n\tint nm_perm = nomount_handle_permission(inode, mask);\n\tif (unlikely(nm_perm < 0)) return nm_perm;\n\tif (unlikely(nm_perm > 0)) return 0;\n#endif\n/s' fs/namei.c
  perl -0777 -pi -e 's/(int inode_permission\(.*?\)\n\{\n\tint retval;\n)/$1#ifdef CONFIG_NOMOUNT\n\tint nm_perm = nomount_handle_permission(inode, mask);\n\tif (unlikely(nm_perm < 0)) return nm_perm;\n\tif (unlikely(nm_perm > 0)) return 0;\n#endif\n/s' fs/namei.c
  echo "  + namei.c"
fi

# --- 5. fs/proc/task_mmu.c (show_map_vma) ---------------------------------
if ! grep -q 'nomount_spoof_mmap_metadata' fs/proc/task_mmu.c; then
  perl -0777 -pi -e 's/(\nstatic void\nshow_map_vma\()/\n#ifdef CONFIG_NOMOUNT\nextern bool nomount_spoof_mmap_metadata(struct inode *inode, dev_t *dev, unsigned long *ino);\n#endif\n$1/' fs/proc/task_mmu.c
  perl -0777 -pi -e 's/(\n\t\tino = inode->i_ino;\n)/$1#ifdef CONFIG_NOMOUNT\n\t\tnomount_spoof_mmap_metadata((struct inode *)inode, &dev, &ino);\n#endif\n/' fs/proc/task_mmu.c
  echo "  + task_mmu.c"
fi

# --- 6. fs/readdir.c (iterate_dir) ----------------------------------------
if ! grep -q 'nomount_handle_iterate_dir' fs/readdir.c; then
  perl -0777 -pi -e 's/(\nint iterate_dir\(struct file \*file, struct dir_context \*ctx\)\n)/\n#ifdef CONFIG_NOMOUNT\nextern int nomount_handle_iterate_dir(struct file *file, struct dir_context *ctx);\n#endif\n$1/' fs/readdir.c
  perl -0777 -pi -e 's/(\n\t\tctx->pos = file->f_pos;\n)(\t\tif \(shared\)\n\t\t\tres = file->f_op->iterate_shared\(file, ctx\);\n\t\telse\n\t\t\tres = file->f_op->iterate\(file, ctx\);\n)/$1#ifdef CONFIG_NOMOUNT\n\t\tres = nomount_handle_iterate_dir(file, ctx);\n#else\n$2#endif\n/s' fs/readdir.c
  # 6.5+ removed the .iterate (non-shared) f_op: the dispatch is a single iterate_shared line.
  perl -0777 -pi -e 's/(\n\t\tctx->pos = file->f_pos;\n)(\t\tres = file->f_op->iterate_shared\(file, ctx\);\n)/$1#ifdef CONFIG_NOMOUNT\n\t\tres = nomount_handle_iterate_dir(file, ctx);\n#else\n$2#endif\n/s' fs/readdir.c
  echo "  + readdir.c"
fi

# --- 7. fs/stat.c (vfs_getattr) -------------------------------------------
if ! grep -q 'nomount_handle_getattr' fs/stat.c; then
  perl -0777 -pi -e 's/(EXPORT_SYMBOL\(vfs_getattr_nosec\);\n)/$1\n#ifdef CONFIG_NOMOUNT\nextern int nomount_handle_getattr(int ret, const struct path *path, struct kstat *stat);\n#endif\n/' fs/stat.c
  perl -0777 -pi -e 's/(\n)(\treturn vfs_getattr_nosec\(path, stat, request_mask, query_flags\);\n)/$1#ifdef CONFIG_NOMOUNT\n\treturn nomount_handle_getattr(vfs_getattr_nosec(path, stat, request_mask, query_flags), path, stat);\n#else\n$2#endif\n/' fs/stat.c
  echo "  + stat.c"
fi

# --- 8. fs/statfs.c (vfs_statfs) ------------------------------------------
if ! grep -q 'nomount_spoof_statfs' fs/statfs.c; then
  perl -0777 -pi -e 's/(#include "internal.h"\n)/$1\n#ifdef CONFIG_NOMOUNT\nextern void nomount_spoof_statfs(const struct path *path, struct kstatfs *buf);\n#endif\n/' fs/statfs.c
  perl -0777 -pi -e 's/(\n\t\tbuf->f_flags = calculate_f_flags\(path->mnt\);\n)/$1#ifdef CONFIG_NOMOUNT\n\tnomount_spoof_statfs(path, buf);\n#endif\n/' fs/statfs.c
  echo "  + statfs.c"
fi

# --- verify every hook CALL SITE landed (not just the extern decl) --------
# grep -F on the actual call statement so an extern-only false-positive can't
# pass when SUSFS/a newer kernel shifts an anchor and the hook silently misses.
echo "=== verification (hook call-sites) ==="
check_call() {  # file  call_substring  min_count
  local f="$1" pat="$2" min="$3" n
  n=$(grep -Fc "$pat" "$f" 2>/dev/null); [ -n "$n" ] || n=0
  if [ "$n" -ge "$min" ]; then
    echo "  ok   $f  ($pat x$n)"
  else
    echo "  FAIL $f  ($pat x$n, need $min) — anchor shifted, hook NOT injected"
    fail=1
  fi
}
check_call fs/d_path.c        'nm_path = nomount_handle_dpath(path, buf, buflen);'  1
check_call fs/namei.c         'result = nomount_handle_getname(result);'            2
check_call fs/namei.c         'nm_perm = nomount_handle_permission(inode, mask);'   2
check_call fs/proc/task_mmu.c 'nomount_spoof_mmap_metadata((struct inode *)inode, &dev, &ino);'     1
check_call fs/readdir.c       'res = nomount_handle_iterate_dir(file, ctx);'        1
check_call fs/stat.c          'return nomount_handle_getattr(vfs_getattr_nosec('    1
check_call fs/statfs.c        'nomount_spoof_statfs(path, buf);'                     1

[ "$fail" -eq 0 ] && echo "NoMount injection OK" || { echo "NoMount injection had failures"; exit 1; }
