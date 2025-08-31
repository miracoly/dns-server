#include <log.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#define PORT 2053

int main(void) {
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0) {
    log_fatal("could not create socket");
    exit(EXIT_FAILURE);
  }

  struct sockaddr_in addr = {0};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(PORT);

  if (bind(sockfd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    log_fatal("could not bind to port");
    close(sockfd);
    exit(EXIT_FAILURE);
  }

  log_info("starting dns server, listening on port 2053");

  return 0;
}
