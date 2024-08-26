#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/time.h>
#include <netdb.h>

#define TARGET "google.com"
#define PORT 80
#define REQUEST "HEAD / HTTP/1.1\r\nHost: " TARGET "\r\nConnection: close\r\n\r\n"
#define TIMEOUT_MS 5000

long measure_http_latency(const char *host, int port)
{
  int sockfd;
  struct addrinfo hints = {0}, *res;
  struct timeval start, end, timeout;
  long latency_ms = -1;

  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;

  if (getaddrinfo(host, NULL, &hints, &res) != 0)
    return -1;

  if ((sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0)
  {
    freeaddrinfo(res);
    return -1;
  }

  ((struct sockaddr_in *)res->ai_addr)->sin_port = htons(port);

  timeout.tv_sec = TIMEOUT_MS / 1000;
  timeout.tv_usec = (TIMEOUT_MS % 1000) * 1000;

  if (setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0)
  {
    close(sockfd);
    freeaddrinfo(res);
    return -1;
  }

  gettimeofday(&start, NULL);
  if (connect(sockfd, res->ai_addr, res->ai_addrlen) < 0)
  {
    close(sockfd);
    freeaddrinfo(res);
    return -1;
  }

  if (send(sockfd, REQUEST, strlen(REQUEST), 0) < 0)
  {
    close(sockfd);
    freeaddrinfo(res);
    return -1;
  }

  gettimeofday(&end, NULL);
  latency_ms = (end.tv_sec - start.tv_sec) * 1000 + (end.tv_usec - start.tv_usec) / 1000;

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