/* SPDX-License-Identifier: GPL-2.0 */
/*
 * SUSFS SELinux Evasion Hooks — Runtime Implementation
 *
 * Compiled into security/selinux/susfs_selinux.o
 * Provides hook implementations for sel_read_policy, security_check_context,
 * and avc_audit to evade SELinux-based detection.
 *
 * Copyright (C) 2024-2026 GKI_KernelSU_SUSFS
 */

#ifdef CONFIG_KSU_SUSFS_SELINUX_EVASION

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/uaccess.h>
#include <linux/cred.h>
#include <linux/uidgid.h>
#include "susfs_selinux.h"

MODULE_LICENSE("GPL");

/*
 * Hook: intercept sel_read_policy to prevent policy inspection.
 *
 * Returns a short spoofed string instead of the real SELinux policy.
 * Injects into security/selinux/selinuxfs.c:sel_read_policy()
 * before the real policy read logic.
 */
int susfs_selinux_hook_read_policy(char __user *buf, size_t count, loff_t *ppos)
{
	static const char spoofed[] = "# SELinux policy (SUSFS evaded)\n";
	loff_t pos = *ppos;

	if (!susfs_selinux_should_evade())
		return -ENOSYS;

	if (pos >= (loff_t)sizeof(spoofed))
		return 0; /* EOF */

	if (count > sizeof(spoofed) - (size_t)pos)
		count = sizeof(spoofed) - (size_t)pos;

	if (copy_to_user(buf, spoofed + pos, count))
		return -EFAULT;

	*ppos = pos + count;
	return (int)count;
}

/*
 * Hook: intercept security_check_context to spoof context validity.
 *
 * Always returns 0 (valid) when evasion is active, regardless of
 * the actual context string. Injects into
 * security/selinux/ss/services.c:security_check_context().
 */
int susfs_selinux_hook_check_context(const char *scontext, u32 scontext_len)
{
	if (!susfs_selinux_should_evade())
		return -ENOSYS;

	/* Report context as always valid */
	return 0;
}

/*
 * Hook: intercept avc_audit to suppress audit messages.
 *
 * Returns 1 (audited, move on) when evasion is active, preventing
 * avc_audit from logging or calling slow_avc_audit().
 * Injects into security/selinux/avc.c:avc_audit().
 */
int susfs_selinux_hook_avc_audit(void)
{
	if (!susfs_selinux_should_evade())
		return -ENOSYS;

	/* Skip audit entirely */
	return 1;
}

EXPORT_SYMBOL(susfs_selinux_hook_read_policy);
EXPORT_SYMBOL(susfs_selinux_hook_check_context);
EXPORT_SYMBOL(susfs_selinux_hook_avc_audit);

#endif /* CONFIG_KSU_SUSFS_SELINUX_EVASION */
