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
#include<cstring>

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
VOLATILE unsigned int *global_middleware_base_vaddr;
Ublox * global_m8_gps;

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
//		/* TIMEPULSE-1: 1 Hz 10% duty. GPS Time */
//		0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x00, 0x01,
//		0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x01, 0x00,
//		0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
//		0x00, 0x80, 0x99, 0x99, 0x99, 0x19, 0x00, 0x00,
//		0x00, 0x00, 0xEF, 0x00, 0x00, 0x00, 0xDF, 0x64,
		/* TIMEPULSE-1: 1 Hz 10% duty. UTC Time, 20delay, invert polarity */
		0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x00, 0x01,
		0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x01, 0x00,
		0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x80, 0x99, 0x99, 0x99, 0x19, 0x00, 0x00,
		0x00, 0x00, 0x6F, 0x00, 0x00, 0x00, 0x41, 0x1C,
		/* TIMEPULSE-2: 1 MHz 50% duty. GPS Time */
		/*0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x01, 0x01,
		0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x01, 0x00,
		0x00, 0x00, 0x40, 0x42, 0x0F, 0x00, 0x00, 0x00,
		0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
		0x00, 0x00, 0xEF, 0x00, 0x00, 0x00, 0x0C, 0x4A*/

		/* TIMEPULSE-2: 1.024 MHz 50% duty. GPS Time */
//		0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x01, 0x01,
//		0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x01, 0x00,
//		0x00, 0x00, 0x00, 0xA0, 0x0F, 0x00, 0x00, 0x00,
//		0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
//		0x00, 0x00, 0xEF, 0x00, 0x00, 0x00, 0x2A, 0x44
		/* TIMEPULSE-2: 1.024 MHz 50% duty lock/unlock. UTC Time,invert polarity, delay 20ns */
		0xB5, 0x62, 0x06, 0x31, 0x20, 0x00, 0x01, 0x01, 
		0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00, 0xA0,
		0x0F, 0x00, 0x00, 0xA0, 0x0F, 0x00, 0x00, 0x00,
		0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 
		0x00, 0x00, 0x6F, 0x00, 0x00, 0x00, 0x3A, 0x8E
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
	global_m8_gps = &M8_Gps_;

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

#define LOGFILE_BASE	"/home/root/"
#define WIFI_LOGFILE	"log.txt"

void* data_logger_loop(void *parm) {
	Ublox *m8_Gps_ = (Ublox*)parm;
	/**
	 * open log files
	 */
	FILE* fp_wifi;
	char logfile_name[200];
	char tmp[100];
	memset(logfile_name,0,200);
	memset(tmp,0,100);
	strcpy(logfile_name, LOGFILE_BASE);

	//wait for GPS validation 2
	while(!m8_Gps_->datetime.valid){
		printf("recv_tester_loop: waiting for GPS validation\n");
		usleep(500 * 1000);
	}

	sprintf(tmp, "%d%d%d-%d-%d-", m8_Gps_->datetime.year,
			m8_Gps_->datetime.month, m8_Gps_->datetime.day,
			m8_Gps_->datetime.hours, m8_Gps_->datetime.minutes);
	strcat(logfile_name, tmp);

	sprintf(tmp, WIFI_LOGFILE);
	strcat(logfile_name, tmp);

	printf("LOG FILE: %s\n", logfile_name);
	fp_wifi = fopen(logfile_name, "a+");
	if(fp_wifi==NULL){
		perror("*******LOG FILE OPEN ERROR********\n");
		exit(0);
	}

	unsigned int curr_frame_len, fi_send_count, fi_recv_count, no_avail_count,request_fail_count, merge_collision;


	while(1) {
		curr_frame_len = (*(global_middleware_base_vaddr+19) & 0xffff0000) >> 16;
		fi_send_count = *(global_middleware_base_vaddr+16);
		fi_recv_count = *(global_middleware_base_vaddr+17);
		no_avail_count = (*(global_middleware_base_vaddr+18) & 0xffff0000) >> 16;
		request_fail_count = (*(global_middleware_base_vaddr+18) & 0x0000ffff);
		merge_collision = (*(global_middleware_base_vaddr+19) & 0x0000ffff);

		fprintf(fp_wifi, "TIME@%-2d:%-2d:%-2d ", m8_Gps_->datetime.hours, m8_Gps_->datetime.minutes, m8_Gps_->datetime.seconds);
		fprintf(fp_wifi, "%-10d %-10d %-10d %-10d %-10d %-10d\n", curr_frame_len, fi_send_count, fi_recv_count, no_avail_count, request_fail_count, merge_collision);
		fflush(fp_wifi);
		usleep(1000 * 1000);
	}

}

void init_ocb(unsigned char node_id){
	system("modprobe ath9k");
	system("iw dev wlan0 set type ocb");
	system("ifconfig wlan0 up");
	system("iw dev wlan0 ocb join 5910 10MHZ");
	system("echo 1 > /sys/kernel/debug/ieee80211/phy0/ath9k/tpc");
	system("/home/root/tools/iwconfig wlan0 txpower 0");

	char tmp[200];
	char tmp2[10];
	memset(tmp,0,200);
	memset(tmp2,0,10);
	strcpy(tmp, "ifconfig wlan0 192.168.1.");
	sprintf(tmp2, "%d", (int)node_id);
	strcat(tmp, tmp2);
	printf(tmp);
	system(tmp);
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
	TDMA_INFO_REQ=0x0b, TDMA_INFO_ACK=0x0c,
	START_EXP_REQ=0x0d, START_EXP_ACK=0x0e,
	REBOOT_REQ = 0x0f, REBOOT_ACK = 0x10
};


//unsigned char zigbee_open_ocb_all[] = {0xfe, 0x05, 0x91, 0x90, 0xff, 0xff, OPEN_OCB_REQ, 0x00, 0xff};
unsigned char zigbee_open_ocb_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, OPEN_OCB_ACK, 0x00, 0xff}; //PC address is 0x0099.
//unsigned char zigbee_check_gps_all[] = {0xfe, 0x05, 0x91, 0x90, 0xff, 0xff, CHECK_GPS_REQ, 0x00, 0xff};
unsigned char zigbee_check_gps_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, CHECK_GPS_ACK, 0x00, 0xff};
unsigned char zigbee_set_frame_len_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, SET_FRAME_LEN_ACK, 0x00, 0xff};
unsigned char zigbee_tdma_start_full_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, TDMA_START_FULL_ACK, 0x00, 0xff};
unsigned char zigbee_tdma_start_basic_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, TDMA_START_BASIC_ACK, 0x00, 0xff};
unsigned char zigbee_start_exp_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, START_EXP_ACK, 0x00, 0xff};
unsigned char zigbee_reboot_ack[] = {0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, REBOOT_ACK, 0x00, 0xff};

void* zigbee_recv_loop(void *parm) {
	int i, bytesread, ocb_inited = 0, tdma_inited = 0, framelen_set = 0, logger_inited = 0;
//	int zcmd_read = 0;
	int zcmd;
	unsigned char frame_len;
	unsigned char* zcmd_buf;
	int loc;
	unsigned char infobuf[100];
	unsigned char tmpbuf[255] = {0xfe, 0x15, 0x91, 0x90, 0x99, 0x00, TDMA_INFO_ACK};
	unsigned int curr_frame_len, fi_send_count, fi_recv_count, no_avail_count,request_fail_count, merge_collision;
	pthread_t dataloggertid;

	serialZigbee zigbee_uart;
	VOLATILE int *middleware_base_vaddr = (VOLATILE int *)parm;
	//set sid of tdma:
	*(middleware_base_vaddr+9) = zigbee_uart.ip_[0];
	//set psf
	*(middleware_base_vaddr+11) = 1;

	while(1) {
		bytesread = zigbee_uart.get_zigbee_data2buf();
	    if(bytesread <= 0){
	    	printf("zigbee_recv_loop: bytes<=0!\n");
	    	exit(0);
	    } else {
	    	if (bytesread != ZCMD_LEN) {
	    		printf("zigbee_recv_loop: bytes %d < ZCMD_LEN!\n", bytesread);
	    	}
//	    	if (zcmd_read < ZCMD_LEN){
//	    		zcmd_read += bytesread;
//	    		printf("recv %d bytes data\n", bytesread);
//	    		if (zcmd_read < ZCMD_LEN)
//	    			continue;
//	    	}
	    	zcmd_buf = zigbee_uart.read_buf(ZCMD_LEN);
			for (i =0; i < bytesread; i++)
				printf("%x ",zcmd_buf[i]);
			printf("\n");
	    }

	    switch(zcmd_buf[ZCMD_LOC]) {
	    case OPEN_OCB_REQ:
	    	zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_open_ocb_ack, ZCMD_LEN);
	    	if (!ocb_inited) {
	    		init_ocb(zigbee_uart.ip_[0]);
	    		ocb_inited = 1;
	    	}
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
	    	if (checkGpsLocked() && framelen_set && !tdma_inited) {
	    		tdma_inited = 1;
	    		*(middleware_base_vaddr+8) = 0xf;
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_full_ack, ZCMD_LEN);
	    		printf("START TDMA FULL \n");
	    	} else if (tdma_inited) {
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_full_ack, ZCMD_LEN);
	    	}
	    	break;
	    case TDMA_START_BASIC_REQ:
	    	if (checkGpsLocked() && framelen_set && !tdma_inited) {
	    		tdma_inited = 1;
	    		*(middleware_base_vaddr+8) = 0x1;
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_basic_ack, ZCMD_LEN);
	    		printf("START TDMA BASIC \n");
	    	} else if (tdma_inited) {
	    		zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_tdma_start_basic_ack, ZCMD_LEN);
	    	}
	    	break;
	    case TDMA_INFO_REQ:

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

//			printf("current_frame_len: %d\n", curr_frame_len );
//			printf("fi_send_count: %d\n", fi_send_count);
//			printf("fi_recv_count: %d\n", fi_recv_count);
//			printf("no_avail_count: %d\n", no_avail_count);
//			printf("request_fail_count: %d\n", request_fail_count);
//			printf("merge_collision: %d\n", merge_collision);

			break;
	    case START_EXP_REQ:
	    	if (!logger_inited) {
	    		pthread_create(&dataloggertid, NULL, data_logger_loop, (void*)global_m8_gps);
	    		logger_inited = 1;
	    	}
	    	zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_start_exp_ack, ZCMD_LEN);
	    	break;
	    case REBOOT_REQ:
	    	zigbee_uart.UART0_Send(zigbee_uart.serialfd_, zigbee_reboot_ack, ZCMD_LEN);
	    	system("reboot -h");
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
	global_middleware_base_vaddr = middleware_base_vaddr;
	pthread_create(&gpstid, NULL, gps_loop, (void*)middleware_base_vaddr);
	pthread_create(&randomtid, NULL, random_loop, (void*)(middleware_base_vaddr+13));
//	pthread_create(&zigbeetid, NULL, zigbee_recv_loop, (void*)middleware_base_vaddr);

	zigbee_recv_loop((void*)middleware_base_vaddr);
//	char c;
//	do {
////		printf("Input e to exit.\n");
////		scanf("%c", &c);
////		getchar();
////		printf("You inputed %c\n", c);
////		if (c=='e')
////			break;
//	}while (1);
	printf("I am About to EXIT!\n");
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


