/*
 * Copyright (C) 2018-2019  Daniel Gröber <dxld@darkboxed.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "builtins.h"
#include "shell.h"
//#include "bashgetopt.h"
#include "common.h"

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sched.h>

int unshare_builtin(WORD_LIST *list)
{
        int rv;
        int unshare_flags = 0;

        int argc;
        char **argv = make_builtin_argv (list, &argc);

	for(int i=1; i < argc; i++) {
		char *ty = argv[i];

		if(strcmp("cgroup", ty) == 0)
			unshare_flags |= CLONE_NEWCGROUP;
		else if(strcmp("ipc", ty) == 0)
			unshare_flags |= CLONE_NEWIPC;
		else if(strcmp("mnt", ty) == 0)
			unshare_flags |= CLONE_NEWNS;
		else if(strcmp("net", ty) == 0)
			unshare_flags |= CLONE_NEWNET;
		else if(strcmp("pid", ty) == 0)
			unshare_flags |= CLONE_NEWPID;
		else if(strcmp("user", ty) == 0)
			unshare_flags |= CLONE_NEWUSER;
		else if(strcmp("uts", ty) == 0)
			unshare_flags |= CLONE_NEWUTS;
		else {
                        builtin_error ("Unknown namespace type '%s'", ty);
                        goto fail;
 		}
	}

	if(unshare_flags == 0)
		return EXECUTION_SUCCESS;

        rv = unshare(unshare_flags);
	if(rv < 0) {
                builtin_error("unshare() failed: %s", strerror(errno));
                goto fail;
	}

        return EXECUTION_SUCCESS;

fail:
        free(argv);
        return EXECUTION_FAILURE;
}

char *unshare_doc[] = {
	"Unshare a processe's namespaces.",
        ""
	"For each ARG the corresponding namespace is unshare()d in turn.",
        "",
        "Valid ARGs are:",
        "",
        "  - cgroup: Cgroup root directory",
        "  - ipc:    System V IPC, POSIX message queues",
        "  - net:    Network devices, stacks, ports, etc.",
        "  - mnt:    Mount points",
        "  - pid:    Process IDs",
        "  - user:   User and group IDs",
        "  - uts:    Hostname and NIS domain name",
	"",
	"For details on the function of each namespace, see unshare(1) or",
        "better yet namespaces(7). This builtin is a trivial wrapper around",
        "unshare(2).",
	(char *)NULL
};

struct builtin unshare_struct = {
	.name = "unshare",
	.function = unshare_builtin,
	.flags = BUILTIN_ENABLED,
	.long_doc = unshare_doc,
	.short_doc = "Usage: unshare cgroup|ipc|mnt|net|pid|user|uts...",
	.handle = 0
};



int chroot_builtin(WORD_LIST *list)
{
        char *path;

        if (list == NULL) {
                builtin_usage();
                return EX_USAGE;
        }

        path = list->word->word;

        if (list->next) {
                builtin_usage();
                return EX_USAGE;
        }

        int rv = chroot(path);
        if(rv < 0) {
                builtin_error("chroot() failed: %s", strerror(errno));
                return EXECUTION_FAILURE;
        }

        return EXECUTION_SUCCESS;
}

char *chroot_doc[] = {
	"Change a process' root directory.",
	"",
	"This is just a trivial wrapper around chroot(2).",
	(char *)NULL
};

struct builtin chroot_struct = {
	.name = "chroot",
	.function = chroot_builtin,
	.flags = BUILTIN_ENABLED,
	.long_doc = chroot_doc,
	.short_doc = "Usage: chroot NEWROOT",
	.handle = 0
};



int pivot_root_builtin(WORD_LIST *list)
{
        char *newroot;
        char *putold;

        if (list == NULL) {
                builtin_usage();
                return EX_USAGE;
        }

        newroot = list->word->word;

        if (!list->next) {
                builtin_usage();
                return EX_USAGE;
        }

        putold = list->next->word->word;

        if (list->next->next) {
                builtin_usage();
                return EX_USAGE;
        }

        int rv = syscall(SYS_pivot_root, newroot, putold);
        if(rv < 0) {
                builtin_error("pivot_root() failed: %s", strerror(errno));
                return EXECUTION_FAILURE;
        }

        return EXECUTION_SUCCESS;
}

char *pivot_root_doc[] = {
	"Change the root filesystem.",
	"",
	"This builtin is just a trivial wrapper around pivot_root(2).",
	(char *)NULL
};

struct builtin pivot_root_struct = {
	.name = "pivot_root",
	.function = pivot_root_builtin,
	.flags = BUILTIN_ENABLED,
	.long_doc = pivot_root_doc,
	.short_doc = "Usage: pivot_root NEW_ROOT PUT_OLD",
	.handle = 0
};



static int common_parse_int(const char *str, int *out_int)
{
        int i;
        int len = strlen(str);
        for(i=0; i < len; i++) {
                if(!isdigit(str[i])) {
                        builtin_error("FD must be integer");
                        return EX_USAGE;
                }
        }

        errno = 0;
        long x = strtol(str, NULL, 10);
        if(errno != 0 || x > INT_MAX || x < INT_MIN) {
                builtin_error("FD must be integer");
                return EX_USAGE;
        }

        *out_int = (int) x;

        return EXECUTION_SUCCESS;
}

int setns_builtin(WORD_LIST *list)
{
        int rv;
        char *path;

        if (list == NULL) {
                builtin_usage();
                return EX_USAGE;
        }

        do {
                char *str = list->word->word;

                int fd;
                rv = common_parse_int(str, &fd);
                if(rv != EXECUTION_SUCCESS)
                        return rv;

                rv = setns(fd, 0);
                if(rv < 0) {
                        builtin_error("setns() failed: %s", strerror(errno));
                        return EXECUTION_FAILURE;
                }

                list = list->next;
        } while(list);

        return EXECUTION_SUCCESS;
}

char *setns_doc[] = {
	"Move a process to an existing namespace.",
	"",
	"This is just a trivial wrapper around setns(2).",
        "",
        "Examples:",
        "",
        "  Enter another process' namespace:"
        "",
        "    $ setns 0 </proc/$PID/ns/net"
        "",
        "  Re-enter an unshare()ed namespace:",
        "",
        "    $ exec {netns}</proc/$PID/ns/net",
        "    $ unshare net",
        "    $ <do stuff...>",
        "    $ setns $netns",
	(char *)NULL
};

struct builtin setns_struct = {
	.name = "setns",
	.function = setns_builtin,
	.flags = BUILTIN_ENABLED,
	.long_doc = setns_doc,
	.short_doc = "Usage: setns FD...",
	.handle = 0
};



int eqns_builtin(WORD_LIST *list)
{
        int rv;
        char *ns1, *ns2;

        if (list == NULL) {
                builtin_usage();
                return EX_USAGE;
        }

        ns1 = list->word->word;

        if (!list->next) {
                builtin_usage();
                return EX_USAGE;
        }

        ns2 = list->next->word->word;

        if (list->next->next) {
                builtin_usage();
                return EX_USAGE;
        }

        int fd1, fd2;

        rv = common_parse_int(ns1, &fd1);
        if(rv != EXECUTION_SUCCESS)
                return rv;

        rv = common_parse_int(ns2, &fd2);
        if(rv != EXECUTION_SUCCESS)
                return rv;

        struct stat st1, st2;

        rv = fstat(fd1, &st1);
        if(rv < 0) {
                builtin_error("fstat() failed: %s", strerror(errno));
                return EXECUTION_FAILURE;
        }

        rv = fstat(fd2, &st2);
        if(rv < 0) {
                builtin_error("fstat() failed: %s", strerror(errno));
                return EXECUTION_FAILURE;
        }

        return (st1.st_dev == st2.st_dev && st1.st_ino == st2.st_ino)
                ? EXECUTION_SUCCESS
                : EXECUTION_FAILURE
                ;
}

char *eqns_doc[] = {
	"Check if two namespace FDs refer to the same namespace.",
	"",
        "Examples:",
        "",
        "    $ exec {ns1}</proc/self/ns/net",
        "    $ exec {ns2}</proc/self/ns/net",
        "    $ exec {ns3}</proc/self/ns/mnt",
        "    $ unshare net",
        "    $ exec {ns4}</proc/self/ns/net",
        "",
        "    $ eqns $ns1 $ns2 && echo true || echo false",
        "      => true",
        "",
        "    $ eqns $ns1 $ns3 && echo true || echo false",
        "      => false",
        "",
        "    $ eqns $ns1 $ns4 && echo true || echo false",
        "      => false",
	(char *)NULL
};

struct builtin eqns_struct = {
	.name = "eqns",
	.function = eqns_builtin,
	.flags = BUILTIN_ENABLED,
	.long_doc = eqns_doc,
	.short_doc = "Usage: eqns FD1 FD2",
	.handle = 0
};
