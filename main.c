#define _POSIX_C_SOURCE 200809L

#include <arpa/inet.h>
#include <log.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#define PORT 2053
#define BUF_SIZE 512

static volatile sig_atomic_t stop = 0;

static void handleSignal(int sig) {
  (void)sig;
  stop = 1;
}

static void registerSignalHandlers(void) {
  struct sigaction sa = {0};
  sa.sa_handler = handleSignal;
  sigemptyset(&sa.sa_mask);
  if (sigaction(SIGINT, &sa, NULL) != 0) {
    log_fatal("could not register signal handler");
    _exit(EXIT_FAILURE);
  }
  if (sigaction(SIGTERM, &sa, NULL) != 0) {
    log_fatal("could not register signal handler");
    _exit(EXIT_FAILURE);
  }
}

int main(void) {
  registerSignalHandlers();

  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0) {
    log_fatal("could not create socket");
    exit(EXIT_FAILURE);
  }

  struct sockaddr_in addr = {0};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(PORT);

  if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) != 0) {
    log_fatal("could not bind to port");
    close(sockfd);
    exit(EXIT_FAILURE);
  }

  log_info("starting dns server, listening on port 2053");

  while (!stop) {
    struct sockaddr_in clientaddr;
    socklen_t clientlen = sizeof(clientaddr);
    char buf[BUF_SIZE + 1];
    struct sockaddr* pclientaddr = (struct sockaddr*)&clientaddr;

    ssize_t n_read =
        recvfrom(sockfd, buf, BUF_SIZE, 0, pclientaddr, &clientlen);
    if (stop) break;
    if (n_read < 0) {
      log_error("could not read from socket");
      continue;
    }

    char ip[INET_ADDRSTRLEN];
    if (inet_ntop(AF_INET, &clientaddr.sin_addr, ip, sizeof(ip)) == NULL) {
      log_error("invalid client ip address");
      continue;
    }
    buf[n_read] = '\0';
    log_info("request from %s: %s", ip, buf);

    ssize_t n_sent = sendto(sockfd, buf, n_read, 0, pclientaddr, clientlen);
    if (n_sent < 0) {
      log_error("could not send to socket");
      continue;
    }
  }

  if (stop) log_warn("received interrupt, shutting down");
  close(sockfd);
  return 0;
}
