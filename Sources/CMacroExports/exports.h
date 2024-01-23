#ifndef exports_h
# define exports_h

# include <stddef.h>
# include <sys/socket.h>

size_t SPI_CMSG_LEN(size_t s);
size_t SPI_CMSG_SPACE(size_t s);

unsigned char *SPI_CMSG_DATA(struct cmsghdr *cmsg);
struct cmsghdr *SPI_CMSG_FIRSTHDR(struct msghdr *msgh);

#endif /* exports_h */
