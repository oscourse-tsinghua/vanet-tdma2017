//============================================================================
// Name        : test.cpp
// Author      : 
// Version     :
// Copyright   : Your copyright notice
// Description : Hello World in C++, Ansi-style
//============================================================================

#include <iostream>
#include <iostream>
#include <stdint.h>
#include <assert.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stddef.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>
#include <fstream>
#include <vector>
using namespace std;

int to_escape_transfer(unsigned char *inbuf, int size, unsigned char *outbuf) {
	int i,j;
	for(i=0,j=0; i<size; i++) {
    	if (inbuf[i] == 0xff) {
    		outbuf[j++] = 0xfe;
    		outbuf[j++] = 0xfd;
    	} else if (inbuf[i] == 0xfe) {
    		outbuf[j++] = 0xfe;
    		outbuf[j++] = 0xfc;
    	} else {
    		outbuf[j++] = inbuf[i];
    	}
	}
	return j;
}

int from_escape_transfer(unsigned char *inbuf, int size, unsigned char *outbuf) {
	int i,j;
	for(i=0,j=0; i<size; i++) {
    	if (inbuf[i] == 0xfe && inbuf[i+1] == 0xfd) {
    		i++;
    		outbuf[j++] = 0xff;
    	} else if (inbuf[i] == 0xfe && inbuf[i+1] == 0xfc) {
    		i++;
    		outbuf[j++] = 0xfe;
    	} else {
    		outbuf[j++] = inbuf[i];
    	}
	}
	return j;
}

int main() {
	unsigned char inbuf[255];
	unsigned char outbuf[255];
	unsigned int num = 0xaaffccfe;
	memcpy(inbuf, &num, 4);
	printf("%x %x %x %x\n", inbuf[0], inbuf[1], inbuf[2], inbuf[3]);
	int n1 = to_escape_transfer(inbuf, 4, outbuf);
	for (int i=0; i<n1; i++){
		printf("%x ", outbuf[i]);
	}
	printf("\n");
	memset(inbuf, 0, 4);
	int n2 = from_escape_transfer(outbuf, n1, inbuf);
	for (int i=0; i<n2; i++){
		printf("%x ", inbuf[i]);
	}
	printf("\n");
	memcpy(&num, inbuf, n2);
	printf("0x%x\n", num);


	int loc;
	unsigned char infobuf[100];
	unsigned char tmpbuf[255] = {0xfe, 0x15, 0x91, 0x90, 0x99, 0x00, 0x01};
	unsigned int curr_frame_len, fi_send_count, fi_recv_count, no_avail_count,request_fail_count, merge_collision;
	curr_frame_len = 0xaabb;
	fi_send_count = 0xffaafffe;
	fi_recv_count = 0xbbfefefe;
	no_avail_count = 0xccff;
	request_fail_count = 0xfeff;
	merge_collision = 0xffaa;

	loc = 7;
	memcpy(infobuf, &curr_frame_len, 2);
	loc += to_escape_transfer(infobuf, 2, tmpbuf+loc);
	memcpy(infobuf, &fi_send_count, 4);
	loc += to_escape_transfer(infobuf, 4, tmpbuf+loc);
	memcpy(infobuf, &fi_recv_count, 4);
	loc += to_escape_transfer(infobuf, 4, tmpbuf+loc);
	memcpy(infobuf, &no_avail_count, 2);
	loc += to_escape_transfer(infobuf, 2, tmpbuf+loc);
	memcpy(infobuf, &request_fail_count, 2);
	loc += to_escape_transfer(infobuf, 2, tmpbuf+loc);
	memcpy(infobuf, &merge_collision, 2);
	loc += to_escape_transfer(infobuf, 2, tmpbuf+loc);
	tmpbuf[loc++] = 0xff;
	for (int i=0; i<loc; i++){
		printf("%x ", tmpbuf[i]);
	}
	printf("\n");

	loc = from_escape_transfer(tmpbuf+7, loc-7, infobuf);
	for (int i=0; i<loc; i++){
		printf("%x ", infobuf[i]);
	}
	printf("\n");
	loc = 0;
	memcpy(&curr_frame_len, infobuf+loc, 2);
	loc += 2;
	memcpy(&fi_send_count, infobuf+loc, 4);
	loc += 4;
	memcpy(&fi_recv_count, infobuf+loc, 4);
	loc += 4;
	memcpy(&no_avail_count, infobuf+loc, 2);
	loc += 2;
	memcpy(&request_fail_count, infobuf+loc, 2);
	loc += 2;
	memcpy(&merge_collision, infobuf+loc, 2);
	loc += 2;
	printf("current_frame_len: %x\n", curr_frame_len );
	printf("fi_send_count: %x\n", fi_send_count);
	printf("fi_recv_count: %x\n", fi_recv_count);
	printf("no_avail_count: %x\n", no_avail_count);
	printf("request_fail_count: %x\n", request_fail_count);
	printf("merge_collision: %x\n", merge_collision);

	return 0;
}

