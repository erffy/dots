#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/ip_icmp.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>

#define TARGET "8.8.8.8"
#define PACKET_SIZE 64
#define TIMEOUT_MS 5000

unsigned short checksum(void *b, int len)
{
    unsigned short *buf = b;
    unsigned int sum = 0;

    while (len > 1)
    {
        sum += *buf++;
        len -= 2;
    }
    if (len == 1)
        sum += *(unsigned char *)buf;

    sum = (sum >> 16) + (sum & 0xFFFF);
    sum += (sum >> 16);
    return ~sum;
}

long get_time_ms()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

long ping(const char *ip_address)
{
    int sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (sockfd < 0)
        return -1;

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    if (inet_pton(AF_INET, ip_address, &addr.sin_addr) <= 0)
        return -1;

    struct timeval timeout = {TIMEOUT_MS / 1000, (TIMEOUT_MS % 1000) * 1000};
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    unsigned char packet[PACKET_SIZE] = {0};
    struct icmphdr icmp_hdr = {ICMP_ECHO, 0, checksum(&icmp_hdr, sizeof(icmp_hdr))};
    memcpy(packet, &icmp_hdr, sizeof(icmp_hdr));

    long start_time = get_time_ms();
    if (sendto(sockfd, packet, sizeof(packet), 0, (struct sockaddr *)&addr, sizeof(addr)) <= 0)
        return -1;

    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(sockfd, &readfds);

    if (select(sockfd + 1, &readfds, NULL, NULL, &timeout) > 0)
    {
        int recv_len = recvfrom(sockfd, packet, sizeof(packet), 0, NULL, NULL);
        if (recv_len > 0)
        {
            struct icmphdr *reply_hdr = (struct icmphdr *)(packet + sizeof(struct iphdr));
            if (reply_hdr->type == ICMP_ECHOREPLY)
                return get_time_ms() - start_time;
        }
    }

    close(sockfd);
    return -1;
}

int main()
{
    long latency_ms = ping(TARGET);
    if (latency_ms < 0 || latency_ms > TIMEOUT_MS)
        printf("{\"text\":\"\", \"tooltip\":\"\", \"class\":\"hidden\"}\n");
    else
        printf("{\"text\":\"   %ldms\", \"tooltip\":\"Target: %s\"}\n", latency_ms, TARGET);

    return 0;
}