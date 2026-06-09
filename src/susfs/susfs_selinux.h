/* SPDX-License-Identifier: GPL-2.0 */
/*
 * SUSFS SELinux Evasion Hooks — Inline stubs & declarations
 *
 * Integrates with existing SUSFS ksu_selinux_hide_enabled mechanism.
 * Hooks intercept selinuxfs reads, context checks, and AVC audits
 * to hide non-standard SELinux rules from userspace detectors.
 *
 * Copyright (C) 2024-2026 GKI_KernelSU_SUSFS
 */

#ifndef _SUSFS_SELINUX_H
#define _SUSFS_SELINUX_H

#ifdef CONFIG_KSU_SUSFS

#include <linux/types.h>
#include <linux/cred.h>
#include <linux/uidgid.h>

/*
 * Check if SELinux evasion should apply to current process.
 * Uses existing SUSFS ksu_selinux_hide_enabled flag (set via ioctl/BRENE).
 * When enabled, hides custom SELinux rules from apps.
 */
extern bool ksu_selinux_hide_enabled;

static inline bool susfs_selinux_should_evade(void)
{
	return ksu_selinux_hide_enabled;
}

/*
 * Check if a context string contains a "hidden" type that should
 * be reported as invalid to userspace. Hidden types include those
 * injected by Magisk/KSU sepolicy (su, magisk, fsck_untrusted, etc.)
 */
bool susfs_selinux_is_hidden_context(const char *context);

/* Hook: sel_read_policy — return cached clean policy instead of live */
extern int susfs_selinux_hook_read_policy(char __user *buf, size_t count,
					  loff_t *ppos, const void *real_policy,
					  size_t real_len);

/* Hook: security_check_context — return -EINVAL for hidden contexts */
extern int susfs_selinux_hook_check_context(const char *scontext,
					    u32 scontext_len);

/* Hook: avc_audit — suppress denials for hidden source/target SIDs */
extern int susfs_selinux_hook_avc_audit(u32 ssid, u32 tsid, u16 tclass,
					u32 requested);

#else /* !CONFIG_KSU_SUSFS */

static inline bool susfs_selinux_should_evade(void) { return false; }
static inline bool susfs_selinux_is_hidden_context(const char *c) { return false; }
static inline int susfs_selinux_hook_read_policy(char __user *b, size_t c,
		loff_t *p, const void *r, size_t rl) { return -ENOSYS; }
static inline int susfs_selinux_hook_check_context(const char *s,
		u32 l) { return -ENOSYS; }
static inline int susfs_selinux_hook_avc_audit(u32 ss, u32 ts, u16 tc,
		u32 r) { return -ENOSYS; }

#endif /* CONFIG_KSU_SUSFS */

#endif /* _SUSFS_SELINUX_H */
