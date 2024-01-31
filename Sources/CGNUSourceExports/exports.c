#define _GNU_SOURCE
#include <unistd.h> /* execvpe */
#include <stdlib.h> /* ptsname */



int spi_execvpe(const char *file, char *const argv[], char *const envp[]) {
	return execvpe(file, argv, envp);
}


char *spi_ptsname(int fd) {
	return ptsname(fd);
}
