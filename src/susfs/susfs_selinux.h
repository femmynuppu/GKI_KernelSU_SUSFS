/* SPDX-License-Identifier: GPL-2.0 */
/*
 * SUSFS SELinux Evasion Hooks
 *
 * Provides hooks into SELinux internals to suppress audit messages,
 * spoof security context checks, and hide policy reads from detection.
 *
 * Copyright (C) 2024-2026 GKI_KernelSU_SUSFS
 */

#ifndef _SUSFS_SELINUX_H
#define _SUSFS_SELINUX_H

#ifdef CONFIG_KSU_SUSFS_SELINUX_EVASION

#include <linux/types.h>
#include <linux/cred.h>
#include <linux/uidgid.h>

/* Check if SELinux evasion should apply to current process */
static inline bool susfs_selinux_should_evade(void)
{
	const struct cred *cred = current_cred();

	/* Only evade for root or KSU manager UID */
	if (uid_eq(cred->uid, GLOBAL_ROOT_UID) ||
	    uid_eq(cred->suid, GLOBAL_ROOT_UID) ||
	    uid_eq(cred->euid, GLOBAL_ROOT_UID))
		return true;

	return false;
}

/* Hook: sel_read_policy - return empty/spoofed policy */
extern int susfs_selinux_hook_read_policy(char __user *buf, size_t count,
					  loff_t *ppos);

/* Hook: security_check_context - always return valid */
extern int susfs_selinux_hook_check_context(const char *scontext,
					    u32 scontext_len);

/* Hook: avc_audit - suppress audit messages, return 1=audited */
extern int susfs_selinux_hook_avc_audit(void);

#else /* !CONFIG_KSU_SUSFS_SELINUX_EVASION */

static inline bool susfs_selinux_should_evade(void) { return false; }
static inline int susfs_selinux_hook_read_policy(char __user *buf, size_t count,
						 loff_t *ppos) { return -ENOSYS; }
static inline int susfs_selinux_hook_check_context(const char *scontext,
						   u32 scontext_len) { return -ENOSYS; }
static inline int susfs_selinux_hook_avc_audit(void) { return -ENOSYS; }

#endif /* CONFIG_KSU_SUSFS_SELINUX_EVASION */

#endif /* _SUSFS_SELINUX_H */
