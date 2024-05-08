# define _XOPEN_SOURCE 600
# include <fcntl.h>
# include <stdlib.h>



int spift_posix_openpt(int fd) {
	return posix_openpt(fd);
}

int spift_grantpt(int fd) {
	return grantpt(fd);
}

int spift_unlockpt(int fd) {
	return unlockpt(fd);
}

char *spift_ptsname(int fd) {
	return ptsname(fd);
}
