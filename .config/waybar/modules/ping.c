#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/time.h>
#include <netdb.h>
#include <time.h>
#include <fcntl.h>

#define TARGET "google.com"
#define PORT 80
#define REQUEST "HEAD / HTTP/1.1\r\nHost: " TARGET "\r\nConnection: close\r\n\r\n"
#define TIMEOUT_MS 5000

long measure_http_latency(const char *host, int port)
{
  int sockfd, flags;
  struct addrinfo hints = {0}, *res;
  struct timespec start, end;
  long latency_ms = -1;

  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;

  if (getaddrinfo(host, NULL, &hints, &res) != 0)
    return -1;

  sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
  if (sockfd < 0)
  {
    freeaddrinfo(res);
    return -1;
  }

  ((struct sockaddr_in *)res->ai_addr)->sin_port = htons(port);

  flags = fcntl(sockfd, F_GETFL, 0);
  fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);

  clock_gettime(CLOCK_MONOTONIC, &start);

  connect(sockfd, res->ai_addr, res->ai_addrlen);

  fd_set writefds;
  struct timeval timeout;

  FD_ZERO(&writefds);
  FD_SET(sockfd, &writefds);

  timeout.tv_sec = TIMEOUT_MS / 1000;
  timeout.tv_usec = (TIMEOUT_MS % 1000) * 1000;

  int sel = select(sockfd + 1, NULL, &writefds, NULL, &timeout);

  if (sel > 0 && FD_ISSET(sockfd, &writefds))
  {
    if (send(sockfd, REQUEST, strlen(REQUEST), 0) > 0)
    {
      clock_gettime(CLOCK_MONOTONIC, &end);
      latency_ms = (end.tv_sec - start.tv_sec) * 1000 + (end.tv_nsec - start.tv_nsec) / 1000000;
    }
  }

  close(sockfd);
  freeaddrinfo(res);   
  return latency_ms;
}

int main()
{
  long latency_ms = measure_http_latency(TARGET, PORT);
  if (latency_ms >= 0 && latency_ms <= TIMEOUT_MS)
    printf("{\"text\":\"   %ldms\", \"tooltip\":\"Target: %s\"}", latency_ms, TARGET);
  else
    printf("{\"text\":\"\", \"tooltip\":\"\",\"class\":\"hidden\"}");

  return 0;
}