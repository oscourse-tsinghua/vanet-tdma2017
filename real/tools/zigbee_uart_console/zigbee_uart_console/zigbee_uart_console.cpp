// zigbee_uart_console.cpp : 定义控制台应用程序的入口点。
//

#include "stdafx.h"

#include <windows.h>
#include <stdio.h>
#include <cstring>
#include <string>
#include<iostream>
#include <string.h>

using namespace std;

HANDLE hCom;//句柄，用于初始化串口

int to_escape_transfer(unsigned char *inbuf, int size, unsigned char *outbuf) {
	int i, j;
	for (i = 0, j = 0; i<size; i++) {
		if (inbuf[i] == 0xff) {
			outbuf[j++] = 0xfe;
			outbuf[j++] = 0xfd;
		}
		else if (inbuf[i] == 0xfe) {
			outbuf[j++] = 0xfe;
			outbuf[j++] = 0xfc;
		}
		else {
			outbuf[j++] = inbuf[i];
		}
	}
	return j;
}

int from_escape_transfer(unsigned char *inbuf, int size, unsigned char *outbuf) {
	int i, j;
	for (i = 0, j = 0; i<size; i++) {
		if (inbuf[i] == 0xfe && inbuf[i + 1] == 0xfd) {
			i++;
			outbuf[j++] = 0xff;
		}
		else if (inbuf[i] == 0xfe && inbuf[i + 1] == 0xfc) {
			i++;
			outbuf[j++] = 0xfe;
		}
		else {
			outbuf[j++] = inbuf[i];
		}
	}
	return j;
}

#define NODENUM 6
enum zigbee_cmd {
	OPEN_OCB_REQ = 0x01, OPEN_OCB_ACK = 0x02,
	CHECK_GPS_REQ = 0x03, CHECK_GPS_ACK = 0x04,
	SET_FRAME_LEN_REQ = 0x05, SET_FRAME_LEN_ACK = 0x06,
	TDMA_START_FULL_REQ = 0x07, TDMA_START_FULL_ACK = 0x08,
	TDMA_START_BASIC_REQ = 0x09, TDMA_START_BASIC_ACK = 0x0a,
	TDMA_INFO_REQ = 0x0b, TDMA_INFO_ACK = 0x0c,
	START_EXP_REQ = 0x0d, START_EXP_ACK = 0x0e,
	REBOOT_REQ = 0x0f, REBOOT_ACK = 0x10,
	ACCESS_SPEED_REQ = 0x11, ACCESS_SPEED_ACK = 0x12,
	SET_SEC_REQ = 0x13, SET_SEC_ACK = 0x14
};
#define ZCMD_LOC 6
#define ZIP_LOC 4
#define ZCMD_LEN 9

unsigned char zigbee_open_ocb_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, OPEN_OCB_REQ, 0x00, 0xff }; //PC address is 0x0099.																			
unsigned char zigbee_check_gps_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, CHECK_GPS_REQ, 0x00, 0xff };
unsigned char zigbee_set_frame_len_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, SET_FRAME_LEN_REQ, 0x00, 0xff };
unsigned char zigbee_tdma_start_full_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, TDMA_START_FULL_REQ, 0x00, 0xff };
unsigned char zigbee_tdma_start_basic_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, TDMA_START_BASIC_REQ, 0x00, 0xff };
unsigned char zigbee_tdma_info_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, TDMA_INFO_REQ, 0x00, 0xff };
unsigned char zigbee_start_exp_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, START_EXP_REQ, 0x00, 0xff };
unsigned char zigbee_reboot_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, REBOOT_REQ, 0x00, 0xff };
unsigned char zigbee_access_speed_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, ACCESS_SPEED_REQ, 0x00, 0xff };
//unsigned char zigbee_set_sec_req[] = { 0xfe, 0x06, 0x91, 0x90, 0x99, 0x00, SET_SEC_REQ, 0x00, 0xff };

int main()
{
	int i, inputcmd, frame_len;
	DWORD writelen, readlen;
	unsigned char readbuf[255];
	unsigned int curr_frame_len[NODENUM], fi_send_count[NODENUM], fi_recv_count[NODENUM], no_avail_count[NODENUM], request_fail_count[NODENUM], merge_collision[NODENUM];
	unsigned int start_time[NODENUM], succ_time[NODENUM], start_sec[NODENUM], start_pulse2[NODENUM], succ_sec[NODENUM], succ_pulse2[NODENUM], delta[NODENUM];
	char sPort[20];
	printf("Input Com port number: \n");
	scanf("%d", &i);
	sprintf(sPort, "\\\\.\\COM%d", i);
	WCHAR wsz[64];
	swprintf(wsz, L"%S", sPort);
	LPCWSTR m_szFilename = wsz;
	printf("you input is %s\n", sPort);
	// 初始化串口
	hCom = CreateFile(m_szFilename, GENERIC_READ | GENERIC_WRITE,0, NULL, OPEN_EXISTING, 0, NULL);

	// 获取和设置串口参数
	DCB myDCB;
	GetCommState(hCom, &myDCB);  // 获取串口参数
	printf("baud rate is %d", (int)myDCB.BaudRate);
	fflush(stdout);
	myDCB.BaudRate = 115200;       // 波特率
	myDCB.Parity = NOPARITY;   // 校验位
	myDCB.ByteSize = 8;          // 数据位
	myDCB.StopBits = ONESTOPBIT; // 停止位
	SetCommState(hCom, &myDCB);  // 设置串口参数

	COMMTIMEOUTS CommTimeOuts;
	CommTimeOuts.ReadIntervalTimeout = 0;    //0xFFFFFFFF;
	CommTimeOuts.ReadTotalTimeoutMultiplier = 0;
	CommTimeOuts.ReadTotalTimeoutConstant = 200;
	CommTimeOuts.WriteTotalTimeoutMultiplier = 0;
	CommTimeOuts.WriteTotalTimeoutConstant = 0;
	SetCommTimeouts(hCom, &CommTimeOuts);

								 // 线程创建
//	HANDLE HRead, HWrite;
//	HWrite = CreateThread(NULL, 0, ThreadWrite, NULL, 0, NULL);
//	HRead = CreateThread(NULL, 0, ThreadRead, NULL, 0, NULL);
	unsigned char tmp[20] = { 0xfe,0x05,0x90,0x21,0,0,0x01,0xff };
	unsigned char infobuf[255];
	unsigned int tdma_start_sec;
	int loc;
	unsigned char tmpbuf[255] = { 0xfe, 0x9, 0x91, 0x90, 0x99, 0x00, SET_SEC_REQ };
	int kk;
	while (1)
	{
		printf("input cmd: \n0 for loop_test\n 1 for Start_OCB\n 2 for ack_gpslocked\n 3 for set_frame_len\n 4 for TDMA_START_FULL\n 5 for TDMA_START_BASIC\n 6 for start_logger\n 7 for start query_remote\n 8 for access speed\n 9 for set start second\n 99 for reboot!!\n" );
		scanf("%d", &inputcmd);
		printf("You input: %d\n", inputcmd);
		switch (inputcmd) {
		case 0:
			
			WriteFile(hCom, tmp, 8, &writelen, NULL);
			ReadFile(hCom, readbuf, 10, &readlen, NULL);   //获取字符串
			if (readlen>0)
			{
				for (int i = 0; i < readlen; i++)
					printf("%x ", readbuf[i]);
				printf("\n");
				fflush(stdout);
			}
			else {
				printf("Looptest TimeOut %d\n", i + 1);
			}
			break;
		case 1:
			for (i = 0; i < NODENUM; i++) {
				zigbee_open_ocb_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_open_ocb_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != OPEN_OCB_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 1.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("Start_OCB TimeOut %d\n", i+1);
				}
			}
			break;
		case 2:
			for (i = 0; i < NODENUM; i++) {
				zigbee_check_gps_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_check_gps_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != CHECK_GPS_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 2.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("Gps_CheckLocked TimeOut %d\n", i + 1);
				}
			}
			break;
		case 3:
			printf("Input frame_len: \n");
			scanf("%d", &frame_len);
			printf("you input: %d\n", frame_len);
			for (i = 0; i < NODENUM; i++) {
				zigbee_set_frame_len_req[ZIP_LOC] = i + 1;
				zigbee_set_frame_len_req[ZCMD_LOC + 1] = frame_len;
				WriteFile(hCom, zigbee_set_frame_len_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != SET_FRAME_LEN_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 3.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("Set_Frame_len TimeOut %d\n", i + 1);
				}
			}
			break;
		case 4:
			for (i = 0; i < NODENUM; i++) {
				zigbee_tdma_start_full_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_tdma_start_full_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != TDMA_START_FULL_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 4.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("Start_Tdma_full TimeOut %d\n", i + 1);
				}
			}
			break;
		case 5:
			for (i = 0; i < NODENUM; i++) {
				zigbee_tdma_start_basic_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_tdma_start_basic_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != TDMA_START_BASIC_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 5.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("TDMA_START_BASIC TimeOut %d\n", i + 1);
				}
			}
			break;
		case 6:
			for (i = 0; i < NODENUM; i++) {
				zigbee_start_exp_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_start_exp_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != START_EXP_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 6.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("Start_exp TimeOut %d\n", i + 1);
				}
			}
			break;
		case 7:
			memset(infobuf, 0, 255);
			for (i = 0; i < NODENUM; i++) {
				curr_frame_len[i] = 0, fi_send_count[i] = 0, fi_recv_count[i] = 0, no_avail_count[i] = 0, request_fail_count[i] = 0, merge_collision[i] = 0;
				zigbee_tdma_info_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_tdma_info_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}
				for (kk = 0; ; kk++) {
					ReadFile(hCom, readbuf+kk, 1, &readlen, NULL);
					if (readlen<=0) {
						printf("query_remote TimeOut %d\n", i + 1);
						goto forcontinue;
					}
					else {
						if (readbuf[kk] == 0xff) {
							for (int i = 0; i < kk+1; i++)
								printf("%x ", readbuf[i]);
							printf("\n");
							break;
						}
					}
				}
				readlen = from_escape_transfer(readbuf + 7, kk - 7, infobuf);
				if (readlen>0)
				{
					for (int j = 0; j<readlen; j++) {
						printf("%x ", infobuf[j]);
					}
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != TDMA_INFO_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 7.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				int loc = 0;
				
				memcpy(&curr_frame_len[i], infobuf + loc, 2);
				loc += 2;
				memcpy(&fi_send_count[i], infobuf + loc, 4);
				loc += 4;
				memcpy(&fi_recv_count[i], infobuf + loc, 4);
				loc += 4;
				memcpy(&no_avail_count[i], infobuf + loc, 2);
				loc += 2;
				memcpy(&request_fail_count[i], infobuf + loc, 2);
				loc += 2;
				memcpy(&merge_collision[i], infobuf + loc, 2);
				loc += 2;
				//printf("current_frame_len: %d\n", curr_frame_len[i]);
				//printf("fi_send_count: %d\n", fi_send_count[i]);
				//printf("fi_recv_count: %d\n", fi_recv_count[i]);
				//printf("no_avail_count: %d\n", no_avail_count[i]);
				//printf("request_fail_count: %d\n", request_fail_count[i]);
				//printf("merge_collision: %d\n", merge_collision[i]);
			forcontinue:
				printf("\n");
			}
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n","Node", 1, 2, 3, 4, 5, 6);
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "curr_frame_len", curr_frame_len[0], curr_frame_len[1], curr_frame_len[2], curr_frame_len[3], curr_frame_len[4], curr_frame_len[5]);
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "fi_send_count", fi_send_count[0], fi_send_count[1], fi_send_count[2], fi_send_count[3], fi_send_count[4], fi_send_count[5]);
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "fi_recv_count", fi_recv_count[0], fi_recv_count[1], fi_recv_count[2], fi_recv_count[3], fi_recv_count[4], fi_recv_count[5]);
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "no_avail_count", no_avail_count[0], no_avail_count[1], no_avail_count[2], no_avail_count[3], no_avail_count[4], no_avail_count[5]);
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "request_fail_count", request_fail_count[0], request_fail_count[1], request_fail_count[2], request_fail_count[3], request_fail_count[4], request_fail_count[5]);
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "merge_collision", merge_collision[0], merge_collision[1], merge_collision[2], merge_collision[3], merge_collision[4], merge_collision[5]);

			break;
		case 8:
			memset(infobuf, 0, 255);
			for (i = 0; i < NODENUM; i++) {
				start_time[i] = 0, succ_time[i] = 0;
				start_sec[i] = 0, start_pulse2[i] = 0, succ_sec[i] = 0, succ_pulse2[i] = 0;
				zigbee_access_speed_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_access_speed_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}
				for (kk = 0; ; kk++) {
					ReadFile(hCom, readbuf + kk, 1, &readlen, NULL);
					if (readlen <= 0) {
						printf("query_remote TimeOut %d\n", i + 1);
						goto forcontinue2;
					}
					else {
						if (readbuf[kk] == 0xff) {
							for (int i = 0; i < kk + 1; i++)
								printf("%x ", readbuf[i]);
							printf("\n");
							break;
						}
					}
				}
				readlen = from_escape_transfer(readbuf + 7, kk - 7, infobuf);
				if (readlen>0)
				{
					for (int j = 0; j<readlen; j++) {
						printf("%x ", infobuf[j]);
					}
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != ACCESS_SPEED_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 8.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				int loc = 0;

				memcpy(&start_time[i], infobuf + loc, 4);
				loc += 4;
				memcpy(&succ_time[i], infobuf + loc, 4);
				loc += 4;
				start_pulse2[i] = start_time[i] & 0xFFFFFFF;
				start_sec[i] = (start_time[i] >> 28) & 0xf;
				succ_pulse2[i] = succ_time[i] & 0xFFFFFFF;
				succ_sec[i] = (succ_time[i] >> 28) & 0xf;
				delta[i] = (start_sec[i] == succ_sec[i]) ? ((succ_pulse2[i] - start_pulse2[i]) << 10) : ((succ_sec[i] - start_sec[i]) - ((start_pulse2[i] - succ_pulse2[i]) << 10));
			forcontinue2:
				printf("\n");
			}
			printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "Node", 1, 2, 3, 4, 5, 6);
			//printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "start_slot", start_sec[0], start_sec[1], start_sec[2], start_sec[3], start_sec[4], start_sec[5]);
			printf("%-30s %-10x %-10x %-10x %-10x %-10x %-10x\n", "succ_slot", succ_time[0], succ_time[1], succ_time[2], succ_time[3], succ_time[4], succ_time[5]);
			//printf("%-30s %-10d %-10d %-10d %-10d %-10d %-10d\n", "delta", delta[0], delta[1], delta[2], delta[3], delta[4], delta[5] );

			break;
		case 9:
			printf("Input sec: \n");
			scanf("%d", &tdma_start_sec);
			printf("you input: %d\n", tdma_start_sec);
			loc = 7;
			memcpy(infobuf, &tdma_start_sec, 4);
			loc += to_escape_transfer(infobuf, 4, tmpbuf + loc);
			tmpbuf[loc++] = 0xff;
			for (i = 0; i < NODENUM; i++) {
				tmpbuf[ZIP_LOC] = i + 1;
//				zigbee_set_sec_req[ZCMD_LOC + 1] = tdma_start_sec;
				WriteFile(hCom, tmpbuf, loc, &writelen, NULL); // 串口发送字符串
				if (writelen != loc) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != SET_SEC_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 3.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("SecSecond TimeOut %d\n", i + 1);
				}
			}
			break;
		case 99:
			for (i = 0; i < NODENUM; i++) {
				zigbee_reboot_req[ZIP_LOC] = i + 1;
				WriteFile(hCom, zigbee_reboot_req, ZCMD_LEN, &writelen, NULL); // 串口发送字符串
				if (writelen != ZCMD_LEN) {
					puts("WriteFile失败");
					return 0;
				}

				ReadFile(hCom, readbuf, ZCMD_LEN, &readlen, NULL);   //获取字符串
				if (readlen>0)
				{
					//printf("%s\n", getputData);
					for (int i = 0; i < readlen; i++)
						printf("%x ", readbuf[i]);
					printf("\n");
					fflush(stdout);
					if (readbuf[ZCMD_LOC] != REBOOT_ACK || readbuf[ZIP_LOC] != i + 1) {
						puts("Something is error in cmd 99.");
						PurgeComm(hCom, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
					}
				}
				else {
					printf("reboot TimeOut %d\n", i + 1);
				}
			}
			break;
		default:goto Exit;
		}

	}

//	CloseHandle(HRead);
//	CloseHandle(HWrite);
Exit:
	return 0;
}
