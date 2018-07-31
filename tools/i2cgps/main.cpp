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

#include "i2c-gps.h"
#include "serial-gps.h"
#include "serial-zigbee.h"
#include "Ublox.h"

#define MAP_SIZE 4096UL
#define MAP_MASK (MAP_SIZE -1)
#define ADDER_BASE_ADDR 0X43C10000
#define MIDDLEWARE_BASE_ADDR 0X43C00000

#define DDR_ADDRESS 0x20000000
#define HP_ADDRES   DDR_ADDRESS
#define VOLATILE
//volatile

using namespace std;

bool timeLocked = false;

unsigned char gps_config[] = {

		/* CFG_NAV5: Platform model: 4-Automotive */
		0xB5, 0x62, 0x06, 0x24, 0x24, 0x00, 0xFF, 0xFF, 0x04,
		0x03, 0x00, 0x00, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00,
		0x05, 0x00, 0xFA, 0x00, 0xFA, 0x00, 0x64, 0x00, 0x5E,
		0x01, 0x00, 0x3C, 0x00, 0x00, 0x00, 0x00, 0xC8, 0x00,
		0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4D, 0x16,

		/* CFG_GNSS: GPS & GLONASS, No SBAS */
		0xB5, 0x62, 0x06, 0x3E, 0x1C, 0x00, 0x00, 0x00,
		0x20, 0x03, 0x00, 0x08, 0x10, 0x00, 0x01, 0x00,
		0x01, 0x01, 0x05, 0x00, 0x03, 0x00, 0x01, 0x00,
		0x01, 0x01, 0x06, 0x08, 0x0E, 0x00, 0x01, 0x00,
		0x01, 0x01, 0xC8, 0xC0,


		/* CFG_SBAS: Disable SBAS */
		0xB5, 0x62, 0x06, 0x16, 0x08, 0x00, 0x00, 0x03,
		0x03, 0x00, 0x51, 0xA2, 0x06, 0x00, 0x23, 0xE7,

		/* CFG-RATE: 1 Hz */
		0xB5, 0x62, 0x06, 0x08, 0x06, 0x00, 0xE8, 0x03,
		0x01, 0x00, 0x01, 0x00, 0x01, 0x39,

		/*timepulse*/
		/* TIMEPULSE-1: 1 Hz 10% duty. GPS Time */
		0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x00, 0x01,
		0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x01, 0x00,
		0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x80, 0x99, 0x99, 0x99, 0x19, 0x00, 0x00,
		0x00, 0x00, 0xEF, 0x00, 0x00, 0x00, 0xDF, 0x64,

		/* TIMEPULSE-2: 1 MHz 50% duty. GPS Time */
		/*0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x01, 0x01,
		0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x01, 0x00,
		0x00, 0x00, 0x40, 0x42, 0x0F, 0x00, 0x00, 0x00,
		0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
		0x00, 0x00, 0xEF, 0x00, 0x00, 0x00, 0x0C, 0x4A*/

		/* TIMEPULSE-2: 1.024 MHz 50% duty. GPS Time */
		0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x01, 0x01, 
		0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x01, 0x00, 
		0x00, 0x00, 0x00, 0xA0, 0x0F, 0x00, 0x00, 0x00, 
		0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 
		0x00, 0x00, 0xEF, 0x00, 0x00, 0x00, 0x2A, 0x44
};

void *getvaddr(int phys_addr)
{
	void *mapped_base;
	int memfd;
	void *mapped_dev_base;
	off_t dev_base = phys_addr;

	memfd = open("/dev/mem", O_RDWR | O_SYNC);
	if(memfd == -1) {
		printf("can't open /dev/mem\n");
		exit(0);
	}

	mapped_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, dev_base & ~MAP_MASK);
	if(mapped_base ==(void*)-1) {
		printf("can't mmap\n");
		exit(0);
	}
	mapped_dev_base = mapped_base + (dev_base & MAP_MASK);
	return 	mapped_dev_base;

}

unsigned int hhmmss2sec(int hh, int mm, int ss)
{
	return hh * 3600 + mm * 60 + ss;
}

void* random_loop(void *parm) {
	VOLATILE unsigned int *dev_base_vaddr = (VOLATILE unsigned int *)parm;
	srand(time(0));
	while (1) {
		*dev_base_vaddr = rand() & 0x1ff;
		usleep(1000);//1ms
	}
}

void* gps_loop(void *parm) {
	Ublox M8_Gps_;
	serialGps gps_serial;
	i2cgps gps;
	bool initflag = false;
	bool ret;
	int bytesread;
	VOLATILE int *dev_base_vaddr = (VOLATILE int *)parm;

	gps.write_gps_config(gps_config, sizeof(gps_config));

	while(1) {
		bytesread = gps_serial.get_gps_data2buf();
	    if(bytesread < 0){
	    	printf("gpsdata_decode_loop: bytes<0!\n");
	    	exit(0);
	    }

		for (int i = 0; i < bytesread; i++) {
			M8_Gps_.encode((char)(gps_serial.gpsdata_buf())[i]);
		}
		if (M8_Gps_.datetime.valid) {
			timeLocked = true;
		}
		if (timeLocked) {
			*(dev_base_vaddr+6) = hhmmss2sec(M8_Gps_.datetime.hours, M8_Gps_.datetime.minutes, M8_Gps_.datetime.seconds);
			*(dev_base_vaddr+5) = 1;
			if (!initflag) {
				initflag = true;
				printf("Time Locked. sec: %d\n",*(dev_base_vaddr+6));
			}
		}
	}
}

void init_ocb(){
	system("modprobe ath9k");
	system("iw dev wlan0 set type ocb");
	system("ifconfig wlan0 up");
	system("iw dev wlan0 ocb join 5910 10MHZ");
}

bool checkGpsLocked(){
	if (timeLocked)
		return true;
	else
		return false;
}

enum zigbee_cmd {
	OPEN_OCB_REQ=0x01, OPEN_OCB_ACK=0x02,
	CHECK_GPS_REQ=0x03, CHECK_GPS_ACK=0x04,
	SET_FRAME_LEN_REQ=0x05, SET_FRAME_LEN_ACK=0x06,
	TDMA_START_FULL_REQ=0x07, TDMA_START_FULL_ACK=0x08,
	TDMA_START_BASIC_REQ=0x09, TDMA_START_BASIC_ACK=0x0a,
	TDMA_INFO_REQ=0x0b, TDMA_INFO_ACK=0x0c
};

#define ZCMD_LOC 6
#define ZCMD_LEN 9
//unsigned char zigbee_open_ocb_all[] = {0xfe, 0x05, 0x91, 0x90, 0xff, 0xff, OPEN_OCB_REQ, 0x00, 0xff};
unsigned char zigbee_open_ocb_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, OPEN_OCB_ACK, 0x00, 0xff}; //PC address is 0x0099.
//unsigned char zigbee_check_gps_all[] = {0xfe, 0x05, 0x91, 0x90, 0xff, 0xff, CHECK_GPS_REQ, 0x00, 0xff};
unsigned char zigbee_check_gps_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, CHECK_GPS_ACK, 0x00, 0xff};
unsigned char zigbee_set_frame_len_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, SET_FRAME_LEN_ACK, 0x00, 0xff};
unsigned char zigbee_tdma_start_full_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, TDMA_START_FULL_ACK, 0x00, 0xff};
unsigned char zigbee_tdma_start_basic_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, TDMA_START_BASIC_ACK, 0x00, 0xff};

void* zigbee_recv_loop(void *parm) {
	int i, bytesread, ocb_inited = 0, tdma_inited = 0, framelen_set = 0;
	int zcmd_read = 0;
	int zcmd;
	unsigned char frame_len;
	unsigned char* zcmd_buf;

	serialZigbee zigbee_uart;
	VOLATILE int *middleware_base_vaddr = (VOLATILE int *)parm;
	//set sid of tdma:
	*(middleware_base_vaddr+9) = zigbee_uart.ip_[0];
	//set psf
	*(middleware_base_vaddr+11) = 1;

	while(1) {
		bytesread = zigbee_uart.get_zigbee_data2buf();
	    if(bytesread < 0){
	    	printf("zigbee_recv_loop: bytes<0!\n");
	    	exit(0);
	    } else {
	    	if (zcmd_read < ZCMD_LEN){
	    		zcmd_read += bytesread;
	    		printf("recv %d bytes data\n", bytesread);
	    		if (zcmd_read < ZCMD_LEN)
	    			continue;
	    	}
	    	zcmd_buf = zigbee_uart.read_buf(ZCMD_LEN);
			for (i =0; i < zcmd_read; i++)
				printf("%x ",zcmd_buf[i]);
			printf("\n");

			zcmd_read -= ZCMD_LEN;
	    }

	    switch(zcmd_buf[ZCMD_LOC]) {
	    case OPEN_OCB_REQ:
	    	if (!ocb_inited) {
	    		init_ocb();
	    		ocb_inited = 1;
	    	}
	    	zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_open_ocb_ack, ZCMD_LEN);
	    	break;
	    case CHECK_GPS_REQ:
	    	if (checkGpsLocked())
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_check_gps_ack, ZCMD_LEN);
	    	break;
	    case SET_FRAME_LEN_REQ:
	    	if (!framelen_set) {
				frame_len = zcmd_buf[ZCMD_LOC+1];
				*(middleware_base_vaddr+14) = frame_len;
				framelen_set = 1;
				zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_set_frame_len_ack, ZCMD_LEN);
				printf("SET FRAME LEN: %d\n", frame_len);
	    	} else {
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_set_frame_len_ack, ZCMD_LEN);
	    	}
	    	break;
	    case TDMA_START_FULL_REQ:
	    	if (!checkGpsLocked() || !framelen_set || !tdma_inited) {
	    		tdma_inited = 1;
	    		*(middleware_base_vaddr+8) = 0xf;
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_full_ack, ZCMD_LEN);
	    		printf("START TDMA FULL \n");
	    	} else if (tdma_inited) {
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_full_ack, ZCMD_LEN);
	    	}
	    	break;
	    case TDMA_START_BASIC_REQ:
	    	if (!checkGpsLocked() || !framelen_set || !tdma_inited) {
	    		tdma_inited = 1;
	    		*(middleware_base_vaddr+8) = 0x1;
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_basic_ack, ZCMD_LEN);
	    		printf("START TDMA BASIC \n");
	    	} else if (tdma_inited) {
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_basic_ack, ZCMD_LEN);
	    	}
	    	break;
	    case TDMA_INFO_REQ:
	    	int loc;
	    	unsigned char infobuf[100];
	    	unsigned char tmpbuf[255] = {0xfe, 0x15, 0x91, 0x90, 0x99, 0x00, TDMA_INFO_ACK};
	    	unsigned int curr_frame_len, fi_send_count, fi_recv_count, no_avail_count,request_fail_count, merge_collision;
	    	curr_frame_len = (*(middleware_base_vaddr+19) & 0xffff0000) >> 16;
	    	fi_send_count = *(middleware_base_vaddr+16);
	    	fi_recv_count = *(middleware_base_vaddr+17);
	    	no_avail_count = (*(middleware_base_vaddr+18) & 0xffff0000) >> 16;
	    	request_fail_count = (*(middleware_base_vaddr+18) & 0x0000ffff);
	    	merge_collision = (*(middleware_base_vaddr+19) & 0x0000ffff);

	    	loc = 7;
	    	memcpy(infobuf, &curr_frame_len, 2);
	    	loc += zigbee_uart.to_escape_transfer(infobuf, 2, tmpbuf+loc);
	    	memcpy(infobuf, &fi_send_count, 4);
	    	loc += zigbee_uart.to_escape_transfer(infobuf, 4, tmpbuf+loc);
	    	memcpy(infobuf, &fi_recv_count, 4);
	    	loc += zigbee_uart.to_escape_transfer(infobuf, 4, tmpbuf+loc);
	    	memcpy(infobuf, &no_avail_count, 2);
	    	loc += zigbee_uart.to_escape_transfer(infobuf, 2, tmpbuf+loc);
	    	memcpy(infobuf, &request_fail_count, 2);
	    	loc += zigbee_uart.to_escape_transfer(infobuf, 2, tmpbuf+loc);
	    	memcpy(infobuf, &merge_collision, 2);
	    	loc += zigbee_uart.to_escape_transfer(infobuf, 2, tmpbuf+loc);
			tmpbuf[loc++] = 0xff;
			zigbee_uart.UART0_Send(zigbee_uart.serialfd_, tmpbuf, loc);

			printf("current_frame_len: %d\n", curr_frame_len );
			printf("fi_send_count: %d\n", fi_send_count);
			printf("fi_recv_count: %d\n", fi_recv_count);
			printf("no_avail_count: %d\n", no_avail_count);
			printf("request_fail_count: %d\n", request_fail_count);
			printf("merge_collision: %d\n", merge_collision);


	    	break;
	    }
	}
}



int main(int argc, char **argv ) {
	pthread_t gpstid;
	pthread_t randomtid;
	pthread_t zigbeetid;
	int i;
	VOLATILE unsigned int *middleware_base_vaddr = (VOLATILE unsigned int *)getvaddr(MIDDLEWARE_BASE_ADDR);
	pthread_create(&gpstid, NULL, gps_loop, (void*)middleware_base_vaddr);
	pthread_create(&randomtid, NULL, random_loop, (void*)(middleware_base_vaddr+13));
	pthread_create(&zigbeetid, NULL, zigbee_recv_loop, (void*)middleware_base_vaddr);
	char c;
	do {
		printf("Input e to exit.\n");
		scanf("%c", &c);
		getchar();
		printf("You inputed %c\n", c);
		if (c=='e')
			break;
	}while (1);

	return 1;
}
int cccmain(int argc, char **argv ) {
	pthread_t gpstid;
	pthread_t pingtid;
	pthread_t randomtid;

	int i;
	VOLATILE unsigned int *dev_base_vaddr = (VOLATILE unsigned int *)getvaddr(ADDER_BASE_ADDR);
	VOLATILE unsigned int *middleware_base_vaddr = (VOLATILE unsigned int *)getvaddr(MIDDLEWARE_BASE_ADDR);

	pthread_create(&gpstid, NULL, gps_loop, (void*)middleware_base_vaddr);
	//pthread_create(&gpstid, NULL, ping_loop, NULL );

	char c;
	do {
		printf("Input e to exit, other to send a pkt.\n");
		scanf("%c", &c);
		getchar();
		printf("You inputed a %c\n", c);
		if (c == 'o') { //普通的发包测试，开启循环功能
			*(dev_base_vaddr+1) = 1;
		} else if (c == 'd') {//普通的发包测试，关闭循环功能
			*(dev_base_vaddr+2) = 1;
		} else if (c == 'b') {
			int bch_pointer;
			printf("Input BCH number (from 1 to 99):\n");
			scanf("%d", &bch_pointer);
			getchar();
			printf("Open TDMA function.\n");
			*(middleware_base_vaddr+8) = 1;
			*(middleware_base_vaddr+7) = bch_pointer;
		} else if (c == 't') {
			int sid,psf,framelen,sw,tmp;
			printf("input sid (0~255)\n");
			scanf("%d", &sid);
			*(middleware_base_vaddr+9) = sid;
			printf("input priority (0~3)\n");
			scanf("%d", &psf);
			*(middleware_base_vaddr+11) = psf;
			printf("input default frame_len: (4/8/16 ..)\n");
			scanf("%d", &framelen);
			*(middleware_base_vaddr+14) = framelen;
			if (framelen == 4) {
				printf("Input random stategy.(99 for random).\n");
				scanf("%d", &tmp);
				if (tmp == 99)
					pthread_create(&randomtid, NULL, random_loop, (void*)(middleware_base_vaddr+13));
				else
					*(middleware_base_vaddr+13) = tmp;
			} else
				pthread_create(&randomtid, NULL, random_loop, (void*)(middleware_base_vaddr+13));
			sw = 0;
			printf("Open TDMA function/slot_adj.\n");
			sw |= 0x3;
			printf("Open frame_len_adj ? \n");
			scanf("%d", &tmp);
			if (tmp)			
				sw |= 0x4;
			
			printf("Open if_single_switch ?\n");
			scanf("%d", &tmp);
			if (tmp)			
				sw |= 0x8;
			printf("0x%x\n", sw);
			*(middleware_base_vaddr+8) = sw;

		} else if (c!='s') {
			printf("reg 18: 0x%x\n", *(middleware_base_vaddr+18));
			printf("reg 19: 0x%x\n", *(middleware_base_vaddr+19));
			printf("current_frame_len: %d\n", (*(middleware_base_vaddr+19) & 0xffff0000) >> 16 );
			printf("frame_count: %d\n", *(middleware_base_vaddr+15));
			printf("fi_send_count: %d\n", *(middleware_base_vaddr+16));
			printf("fi_recv_count: %d\n", *(middleware_base_vaddr+17));
			printf("no_avail_count: %d\n", (*(middleware_base_vaddr+18) & 0xffff0000) >> 16);
			printf("request_fail_count: %d\n", (*(middleware_base_vaddr+18) & 0x0000ffff));
			printf("merge_collision: %d\n", (*(middleware_base_vaddr+19) & 0x0000ffff));
		} else if (c!='e') {
			unsigned int repeatnum;
			int delta_t, temp,roundnum;
			printf("Input pkt num per round:\n");
			scanf("%d", &repeatnum);
			printf("Input round num:\n");
			scanf("%d", &roundnum);
			
			temp = 0;
			//printf("Pkt num: %d, repeat %d\n, round %d\n", *(dev_base_vaddr+1), repeatnum, roundnum);
			ofstream fp;
			fp.open("/sendpkt_res.txt", ios::in|ios::out|ios::binary|ios::trunc);
			if (!fp.is_open())
				cout << "Result file open failed!" << endl;
			while (roundnum--) {
				usleep(1000);
				*(dev_base_vaddr+2) = repeatnum;
				delta_t = *(dev_base_vaddr+3);
				*dev_base_vaddr = 1;
				int tt = 0;
				while (1) {
					delta_t = *(dev_base_vaddr+3);
					if (delta_t > 5000 || delta_t < 0)
						continue;
					if (delta_t != temp) {
						printf("delta_t: %d us\n", delta_t);
						temp = delta_t;
						tt++;
					}
					if (tt == repeatnum)
						break;
					usleep(50);
				}
				fp << delta_t << endl;
			}
			fp.close();
		}

	} while(c!='e');
	printf("Exit!\n");

	return 1;
}


