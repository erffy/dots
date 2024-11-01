// -lcjson

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/ip_icmp.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <cjson/cJSON.h>

#define __DEFAULT_TARGET "8.8.8.8"
#define __DEFAULT_PACKET_SIZE 64
#define __DEFAULT_TIMEOUT 5000
#define MAX_CONFIG_SIZE (5 * 1024)

typedef struct
{
    char *TARGET;
    int PACKET_SIZE;
    int TIMEOUT;
} Config;

Config config = {NULL, __DEFAULT_PACKET_SIZE, __DEFAULT_TIMEOUT};

static void set_default_config(Config *cfg)
{
    if (cfg->TARGET != NULL)
    {
        free(cfg->TARGET);
    }
    cfg->TARGET = strdup(__DEFAULT_TARGET);
    if (!cfg->TARGET)
    {
        fprintf(stderr, "Memory allocation failed for default target\n");
        exit(1);
    }
    cfg->PACKET_SIZE = __DEFAULT_PACKET_SIZE;
    cfg->TIMEOUT = __DEFAULT_TIMEOUT;
}

static inline size_t get_file_size(FILE *file)
{
    struct stat st;
    if (fstat(fileno(file), &st) == 0)
        return st.st_size;

    return 0;
}

static char *read_file_efficient(const char *filename, size_t *size)
{
    FILE *file = fopen(filename, "rb");
    if (!file)
        return NULL;

    size_t file_size = get_file_size(file);
    if (file_size == 0 || file_size > MAX_CONFIG_SIZE)
    {
        fclose(file);
        return NULL;
    }

    char *buffer = (char *)malloc(file_size + 1);
    if (!buffer)
    {
        fclose(file);
        return NULL;
    }

    size_t bytes_read = fread(buffer, 1, file_size, file);
    fclose(file);

    if (bytes_read != file_size)
    {
        free(buffer);
        return NULL;
    }

    buffer[file_size] = '\0';
    if (size)
        *size = file_size;
    return buffer;
}

void load_config(const char *filename, Config *config)
{
    set_default_config(config);

    size_t file_size;
    char *buffer = read_file_efficient(filename, &file_size);
    if (!buffer)
        return;

    cJSON *json = cJSON_ParseWithLength(buffer, file_size);
    free(buffer);
    if (!json)
        return;

    cJSON *target = cJSON_GetObjectItem(json, "TARGET");
    if (cJSON_IsString(target) && target->valuestring)
    {
        free(config->TARGET);
        config->TARGET = strdup(target->valuestring);
        if (!config->TARGET)
            config->TARGET = strdup(__DEFAULT_TARGET);
    }

    cJSON *packet_size = cJSON_GetObjectItem(json, "PACKET_SIZE");
    if (cJSON_IsNumber(packet_size))
        config->PACKET_SIZE = packet_size->valueint;

    cJSON *timeout = cJSON_GetObjectItem(json, "TIMEOUT");
    if (cJSON_IsNumber(timeout))
        config->TIMEOUT = timeout->valueint;

    cJSON_Delete(json);
}

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
    char config_path[256];
    snprintf(config_path, sizeof(config_path), "%s/.config/ping.json", getenv("HOME"));

    load_config(config_path, &config);

    int sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (sockfd < 0)
        return -1;

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    if (inet_pton(AF_INET, ip_address, &addr.sin_addr) <= 0)
        return -1;

    struct timeval timeout = {config.TIMEOUT / 1000, (config.TIMEOUT % 1000) * 1000};
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    int packet_size = sizeof(struct icmphdr) + config.PACKET_SIZE;
    char *packet = calloc(packet_size, sizeof(char));
    if (!packet)
    {
        perror("Memory allocation failed for packet");
        close(sockfd);
        exit(1);
    }

    struct icmphdr icmp_hdr = {ICMP_ECHO, 0, checksum(&icmp_hdr, sizeof(icmp_hdr))};
    memcpy(packet, &icmp_hdr, sizeof(icmp_hdr));

    long start_time = get_time_ms();
    if (sendto(sockfd, packet, sizeof(packet), 0, (struct sockaddr *)&addr, sizeof(addr)) <= 0)
    {
        free(packet);
        close(sockfd);
        return -1;
    }

    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(sockfd, &readfds);

    long result = -1;
    if (select(sockfd + 1, &readfds, NULL, NULL, &timeout) > 0)
    {
        int recv_len = recvfrom(sockfd, packet, sizeof(packet), 0, NULL, NULL);
        if (recv_len > 0)
        {
            struct icmphdr *reply_hdr = (struct icmphdr *)(packet + sizeof(struct iphdr));
            if (reply_hdr->type == ICMP_ECHOREPLY)
                result = get_time_ms() - start_time;
        }
    }

    free(packet);
    close(sockfd);
    return result;
}

int main()
{
    long latency_ms = ping(config.TARGET ? config.TARGET : __DEFAULT_TARGET);
    if (latency_ms < 0 || latency_ms > config.TIMEOUT)
        printf("{\"text\":\"\", \"tooltip\":\"\", \"class\":\"hidden\"}\n");
    else
        printf("{\"text\":\"   %ldms\", \"tooltip\":\"Target: %s\"}\n",
               latency_ms,
               config.TARGET ? config.TARGET : __DEFAULT_TARGET);

    if (config.TARGET)
        free(config.TARGET);
    return 0;
}