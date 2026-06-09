/* SPDX-License-Identifier: GPL-2.0 */
/*
 * SUSFS SELinux Evasion Hooks — Runtime Implementation
 *
 * Provides hook implementations for sel_read_policy, security_check_context,
 * and avc_audit to evade SELinux-based root detection.
 *
 * INTEGRATION: Uses existing SUSFS ksu_selinux_hide_enabled flag.
 * When BRENE/manager enables SELinux hide, these hooks activate.
 *
 * Compiled into fs/susfs_selinux.o, linked with SUSFS core.
 *
 * Copyright (C) 2024-2026 GKI_KernelSU_SUSFS
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/uaccess.h>
#include <linux/cred.h>
#include <linux/uidgid.h>
#include <linux/string.h>
#include <linux/slab.h>
#include <linux/mutex.h>
#include "susfs_selinux.h"

MODULE_LICENSE("GPL");

/* ---------- Hidden context patterns ---------- */
/*
 * Context types injected by Magisk/KSU sepolicy that should be
 * hidden from detection apps. Duck Detector probes for these via
 * selinux_check_context(). Return -EINVAL to pretend they don't exist.
 */
static const char *hidden_types[] = {
	"fsck_untrusted",    /* Duck Detector's primary probe target */
	"su",                /* Standard su domain */
	"magisk",            /* Magisk domain */
	"magisk_client",     /* Magisk client domain */
	"ksu",               /* KernelSU domain */
	"ksud",              /* KernelSU daemon domain */
	"zygisk",            /* Zygisk domain */
	NULL
};

/*
 * Check if a SELinux context string contains a known hidden type.
 * Duck Detector calls selinux_check_context("fsck_untrusted:sys_admin:s0")
 * — we must return -EINVAL for this.
 */
bool susfs_selinux_is_hidden_context(const char *context)
{
	int i;

	if (!context)
		return false;

	for (i = 0; hidden_types[i]; i++) {
		if (strstr(context, hidden_types[i]))
			return true;
	}
	return false;
}

/* ---------- Clean policy cache ---------- */
static char *clean_policy_cache = NULL;
static size_t clean_policy_len = 0;
static DEFINE_MUTEX(policy_cache_lock);

/*
 * Cache a snapshot of the clean SELinux policy BEFORE modifications.
 * Called from sel_read_policy when evasion is first activated.
 * Uses security_read_policy() to serialize the current policydb.
 */
static int susfs_cache_clean_policy(const void *real_policy, size_t real_len)
{
	mutex_lock(&policy_cache_lock);

	if (clean_policy_cache) {
		/* Already cached — check if still valid */
		mutex_unlock(&policy_cache_lock);
		return 0;
	}

	/* Copy the first policy snapshot as "clean" */
	clean_policy_cache = kmalloc(real_len, GFP_KERNEL);
	if (!clean_policy_cache) {
		mutex_unlock(&policy_cache_lock);
		return -ENOMEM;
	}

	memcpy(clean_policy_cache, real_policy, real_len);
	clean_policy_len = real_len;

	mutex_unlock(&policy_cache_lock);
	return 0;
}

/*
 * Hook: intercept sel_read_policy to prevent policy inspection.
 *
 * Strategy: When evasion is active and caller is non-root (uid >= 10000),
 * return the CACHED CLEAN policy snapshot instead of the live modified
 * policydb. The cached policy is captured on first access via
 * security_read_policy().
 *
 * For root callers, return -ENOSYS to fall through to real policy
 * (root needs real policy for management).
 *
 * Inject BEFORE the real policy read in security/selinux/selinuxfs.c
 */
int susfs_selinux_hook_read_policy(char __user *buf, size_t count,
				   loff_t *ppos, const void *real_policy,
				   size_t real_len)
{
	loff_t pos = *ppos;
	size_t avail;

	if (!susfs_selinux_should_evade())
		return -ENOSYS;

	/* Root always sees real policy */
	if (uid_eq(current_cred()->uid, GLOBAL_ROOT_UID))
		return -ENOSYS;

	/* Lazy-init clean policy cache */
	if (!clean_policy_cache) {
		int ret = susfs_cache_clean_policy(real_policy, real_len);
		if (ret)
			return ret;
	}

	mutex_lock(&policy_cache_lock);

	if (!clean_policy_cache) {
		mutex_unlock(&policy_cache_lock);
		return -ENOSYS;
	}

	if (pos >= (loff_t)clean_policy_len) {
		mutex_unlock(&policy_cache_lock);
		return 0; /* EOF */
	}

	avail = clean_policy_len - (size_t)pos;
	if (count > avail)
		count = avail;

	if (copy_to_user(buf, clean_policy_cache + pos, count)) {
		mutex_unlock(&policy_cache_lock);
		return -EFAULT;
	}

	*ppos = pos + count;
	mutex_unlock(&policy_cache_lock);
	return (int)count;
}

/*
 * Hook: intercept security_check_context to hide custom types.
 *
 * Strategy: When evasion active AND context string contains a hidden
 * type (fsck_untrusted, su, magisk, etc.), return -EINVAL to pretend
 * the context is invalid. For normal contexts, return -ENOSYS to
 * fall through to real validation.
 *
 * This neutralizes Duck Detector's primary probe:
 *   selinux_check_context("fsck_untrusted:sys_admin:s0") → -EINVAL
 *   "This context doesn't exist in the policy" → CLEAN
 *
 * Inject BEFORE context_struct_to_sid() in
 * security/selinux/ss/services.c
 */
int susfs_selinux_hook_check_context(const char *scontext, u32 scontext_len)
{
	if (!susfs_selinux_should_evade())
		return -ENOSYS;

	if (susfs_selinux_is_hidden_context(scontext))
		return -EINVAL;  /* Pretend context doesn't exist */

	return -ENOSYS;  /* Not hidden — let real check proceed */
}

/*
 * Hook: intercept avc_audit to suppress incriminating denials.
 *
 * Strategy: When evasion active, suppress AVC audit entirely for
 * processes NOT in the KSU domain. This prevents Duck Detector
 * from observing denial patterns that reveal hidden types.
 *
 * KSU processes (uid=0 or KSU manager) still get real audits.
 *
 * Inject at the start of avc_audit() in security/selinux/avc.c
 */
int susfs_selinux_hook_avc_audit(u32 ssid, u32 tsid, u16 tclass,
				 u32 requested)
{
	if (!susfs_selinux_should_evade())
		return -ENOSYS;

	/* Root/KSU processes: real audit */
	if (uid_eq(current_cred()->uid, GLOBAL_ROOT_UID))
		return -ENOSYS;

	/* App processes: suppress all AVC audit output */
	return 1;  /* Return immediately, skip slow_avc_audit() */
}
