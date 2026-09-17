#!/bin/bash
# ReSukiSU manual hook patches for non-GKI kernel (gauguin 4.19)
# Based on ReSukiSU setup.sh method
# Required hooks: fs/stat.c, fs/exec.c, fs/open.c, kernel/reboot.c
# Config macro: CONFIG_KSU_MANUAL_HOOK

patch_files=(
    fs/stat.c
    fs/exec.c
    fs/open.c
    kernel/reboot.c
)

for i in "${patch_files[@]}"; do

    if grep -q "CONFIG_KSU_MANUAL_HOOK" "$i"; then
        echo "Warning: $i already contains ReSukiSU manual hook"
        continue
    fi

    case $i in

    # fs/stat.c - stat/fstat/fstatat hooks
    fs/stat.c)
        # Hook newfstatat
        if grep -q "SYSCALL_DEFINE4(newfstatat" "$i"; then
            sed -i '/SYSCALL_DEFINE4(newfstatat/i\
#ifdef CONFIG_KSU_MANUAL_HOOK\
__attribute__((hot))\
extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\
extern void ksu_handle_newfstat_ret(unsigned int *fd, struct stat __user **statbuf_ptr);\
#if defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_COMPAT_STAT64)\
extern void ksu_handle_fstat64_ret(unsigned long *fd, struct stat64 __user **statbuf_ptr);\
#endif\
#endif' "$i"
            sed -i '/int error;/a\
#ifdef CONFIG_KSU_MANUAL_HOOK\
\tksu_handle_stat(&dfd, &filename, &flag);\
#endif' "$i"
        fi
        # Hook newfstat (32-bit)
        if grep -q "SYSCALL_DEFINE2(newfstat" "$i"; then
            sed -i '/SYSCALL_DEFINE2(newfstat/,/return error;/{/return error;/i\
#ifdef CONFIG_KSU_MANUAL_HOOK\
\tksu_handle_newfstat_ret(&fd, &statbuf);\
#endif
            }' "$i"
        fi
        # Hook fstat64 (32-bit)
        if grep -q "SYSCALL_DEFINE2(fstat64" "$i"; then
            sed -i '/SYSCALL_DEFINE2(fstat64/,/return error;/{/return error;/i\
#ifdef CONFIG_KSU_MANUAL_HOOK // for 32-bit\
\tksu_handle_fstat64_ret(&fd, &statbuf);\
#endif
            }' "$i"
        fi
        # Hook fstatat64 (32-bit)
        if grep -q "SYSCALL_DEFINE4(fstatat64" "$i"; then
            sed -i '/SYSCALL_DEFINE4(fstatat64/i\
#ifdef CONFIG_KSU_MANUAL_HOOK\
__attribute__((hot))\
extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\
#endif' "$i"
            sed -i '/SYSCALL_DEFINE4(fstatat64/,/int error;/{/int error;/a\
#ifdef CONFIG_KSU_MANUAL_HOOK // 32-bit su\
\tksu_handle_stat(&dfd, &filename, &flag);\
#endif
            }' "$i"
        fi
        ;;

    # fs/exec.c - execve hooks
    fs/exec.c)
        # Hook do_execve
        sed -i '/int do_execve(struct filename \\*filename/i\
#ifdef CONFIG_KSU_MANUAL_HOOK\
__attribute__((hot))\
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr,\
\t\t\tvoid *argv, void *envp, int *flags);\
#endif' "$i"
        sed -i '/int do_execve(struct filename \\*filename/,/return do_execveat_common(AT_FDCWD, filename, argv, envp, 0);/{/struct user_arg_ptr envp = { .ptr.native = __envp };/a\
#ifdef CONFIG_KSU_MANUAL_HOOK\
\tksu_handle_execveat((int *)AT_FDCWD, &filename, &argv, &envp, 0);\
#endif
        }' "$i"
        # Hook compat_do_execve (32-bit)
        sed -i '/static int compat_do_execve(struct filename \\*filename/,/return do_execveat_common(AT_FDCWD, filename, argv, envp, 0);/{/\.ptr.compat = __envp,/a\
#ifdef CONFIG_KSU_MANUAL_HOOK // 32-bit ksud and 32-on-64 support\
\tksu_handle_execveat((int *)AT_FDCWD, &filename, &argv, &envp, 0);\
#endif
        }' "$i"
        ;;

    # fs/open.c - faccessat hook
    fs/open.c)
        sed -i '/SYSCALL_DEFINE3(faccessat/i\
#ifdef CONFIG_KSU_MANUAL_HOOK\
__attribute__((hot))\
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode, int *flags);\
#endif' "$i"
        sed -i '/SYSCALL_DEFINE3(faccessat/,/return do_faccessat/{/return do_faccessat/i\
#ifdef CONFIG_KSU_MANUAL_HOOK\
\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\
#endif
        }' "$i"
        ;;

    # kernel/reboot.c - sys_reboot hook
    kernel/reboot.c)
        sed -i '/SYSCALL_DEFINE4(reboot/i\
#ifdef CONFIG_KSU_MANUAL_HOOK\
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\
#endif' "$i"
        sed -i '/SYSCALL_DEFINE4(reboot/,/int ret = 0;/{/int ret = 0;/a\
#ifdef CONFIG_KSU_MANUAL_HOOK\
\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\
#endif
        }' "$i"
        ;;

    esac
done
