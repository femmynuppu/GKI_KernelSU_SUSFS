#ifdef CONFIG_ZEROMOUNT
static inline int zeromount_stat_hook(int dfd, const char __user *filename,
                                      struct kstat *stat, unsigned int request_mask,
                                      int flags) {
    if (zm_is_recursive() || IS_ERR_OR_NULL(filename)) return -ENOENT;
    if (filename) {
        char kname[NAME_MAX + 1];
        long copied = strncpy_from_user(kname, filename, sizeof(kname));
        if (copied > 0 && kname[0] != '/') {
            char *abs_path = zeromount_build_absolute_path(dfd, kname);
            if (abs_path) {
                char *resolved = zeromount_resolve_path(abs_path);
                if (resolved) {
                    struct path zm_path;
                    int zm_ret;
                    zm_enter();
                    zm_ret = kern_path(resolved, (flags & AT_SYMLINK_NOFOLLOW) ? 0 : LOOKUP_FOLLOW, &zm_path);
                    zm_exit();
                    kfree(resolved);
                    kfree(abs_path);
                    if (zm_ret == 0) {
                        zm_ret = vfs_getattr(&zm_path, stat, request_mask,
                                             (flags & AT_SYMLINK_NOFOLLOW) ? AT_SYMLINK_NOFOLLOW : 0);
                        path_put(&zm_path);
                        return zm_ret;
                    }
                } else {
                    kfree(abs_path);
                }
            }
        }
    }
    return -ENOENT;
}
#endif
