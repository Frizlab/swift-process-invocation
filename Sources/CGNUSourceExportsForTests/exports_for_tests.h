#ifndef exports_for_tests_h
# define exports_for_tests_h

/* We need posix_openpt, grantpt, unlockpt and ptsname. */
# define _XOPEN_SOURCE 600
# include <fcntl.h>
# include <stdlib.h>

#endif /* exports_for_tests_h */
