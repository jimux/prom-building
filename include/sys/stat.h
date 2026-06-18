/*
 * sys/stat.h -- Minimal standalone version for IP54 PROM build.
 *
 * XFS and EFS standalone code include sys/stat.h but do not use
 * struct stat members directly.
 */
#ifndef __SYS_STAT_H__
#define __SYS_STAT_H__

#include <sys/types.h>

/* Basic stat types */
#ifndef _MODE_T
#define _MODE_T
typedef __uint32_t  mode_t;
#endif
#ifndef _NLINK_T
#define _NLINK_T
typedef __uint32_t  nlink_t;
#endif
typedef __int64_t   blkcnt_t;
typedef __int64_t   blkcnt64_t;
typedef __int64_t   off64_t;
typedef __uint64_t  ino64_t;
#ifndef _INO_T
#define _INO_T
typedef __uint32_t  ino_t;
#endif

/* File type macros */
#define S_IFMT   0170000
#define S_IFSOCK 0140000
#define S_IFLNK  0120000
#define S_IFREG  0100000
#define S_IFBLK  0060000
#define S_IFDIR  0040000
#define S_IFCHR  0020000
#define S_IFIFO  0010000
#define S_ISUID  0004000
#define S_ISGID  0002000
#define S_ISVTX  0001000

#define S_ISREG(m)  (((m) & S_IFMT) == S_IFREG)
#define S_ISDIR(m)  (((m) & S_IFMT) == S_IFDIR)
#define S_ISCHR(m)  (((m) & S_IFMT) == S_IFCHR)
#define S_ISBLK(m)  (((m) & S_IFMT) == S_IFBLK)
#define S_ISFIFO(m) (((m) & S_IFMT) == S_IFIFO)
#define S_ISLNK(m)  (((m) & S_IFMT) == S_IFLNK)
#define S_ISSOCK(m) (((m) & S_IFMT) == S_IFSOCK)

#define S_IRWXU 0000700
#define S_IRUSR 0000400
#define S_IWUSR 0000200
#define S_IXUSR 0000100
#define S_IRWXG 0000070
#define S_IRGRP 0000040
#define S_IWGRP 0000020
#define S_IXGRP 0000010
#define S_IRWXO 0000007
#define S_IROTH 0000004
#define S_IWOTH 0000002
#define S_IXOTH 0000001

struct stat {
    dev_t       st_dev;
    ino_t       st_ino;
    mode_t      st_mode;
    nlink_t     st_nlink;
    uid_t       st_uid;
    gid_t       st_gid;
    dev_t       st_rdev;
    off_t       st_size;
    long        st_atime;
    long        st_mtime;
    long        st_ctime;
    long        st_blksize;
    blkcnt_t    st_blocks;
};

struct stat64 {
    dev_t       st_dev;
    ino64_t     st_ino;
    mode_t      st_mode;
    nlink_t     st_nlink;
    uid_t       st_uid;
    gid_t       st_gid;
    dev_t       st_rdev;
    off64_t     st_size;
    long        st_atime;
    long        st_mtime;
    long        st_ctime;
    long        st_blksize;
    blkcnt64_t  st_blocks;
};

#endif /* __SYS_STAT_H__ */
