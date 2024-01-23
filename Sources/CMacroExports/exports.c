#include <stddef.h>
#include <sys/socket.h>

#include "include/exports.h"



size_t SPI_CMSG_LEN(size_t s) {
	return CMSG_LEN(s);
}

size_t SPI_CMSG_SPACE(size_t s) {
	return CMSG_SPACE(s);
}


unsigned char *SPI_CMSG_DATA(struct cmsghdr *cmsg) {
	return CMSG_DATA(cmsg);
}

struct cmsghdr *SPI_CMSG_FIRSTHDR(struct msghdr *msgh) {
	return CMSG_FIRSTHDR(msgh);
}
