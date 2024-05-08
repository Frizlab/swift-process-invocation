#ifndef exports_for_tests_h
# define exports_for_tests_h

/* We need posix_openpt, grantpt, unlockpt and ptsname.
 * Using the following used to work but does not anymore.
 * AFAIU this is due to the `stat` struct being exported by this module and
 *  being different than the one in CDispatch due to the `_XOPEN_SOURCE` define.
 * So instead we write shims. */
//# define _XOPEN_SOURCE 600
//# include <fcntl.h>
//# include <stdlib.h>

int spift_posix_openpt(int);
int spift_grantpt(int);
int spift_unlockpt(int);
char *spift_ptsname(int);

#endif /* exports_for_tests_h */
