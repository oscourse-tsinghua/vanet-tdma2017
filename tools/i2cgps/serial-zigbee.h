/*
 * serial-zigbee.h
 *
 *  Created on: Jul 31, 2018
 *      Author: wu
 */

#ifndef SERIAL_ZIGBEE_H_
#define SERIAL_ZIGBEE_H_

/* baudrate settings are defined in <asm/termbits.h>, which is
   included by <termios.h> */
//#define BAUDRATE B115200   // Change as needed, keep B

/* change this definition for the correct port */
#define ZIGBEEDEVICE "/dev/ttyUL1" //picozed serial port

#define _POSIX_SOURCE 1 /* POSIX compliant source */

#define FALSE 0
#define TRUE 1
typedef unsigned char		u8;

#define BUFFER_SIZE			255

#define ZCMD_LOC 6
#define ZCMD_LEN 9

class serialZigbee{
public:

	int size_;
	int serialfd_;
	unsigned char ip_[2];
	serialZigbee();
	~serialZigbee();
	int init(void);
	unsigned char* read_buf(int size);
	int UART0_Send(int fd, unsigned char *send_buf,int data_len);
	int get_zigbee_data2buf(void);
	int to_escape_transfer(unsigned char *inbuf, int size, unsigned char *outbuf);
	int from_escape_transfer(unsigned char *inbuf, int size, unsigned char *outbuf);
private:
	u8 *rdbuf_;

	int UART0_Set(int fd,int speed,int flow_ctrl,int databits,int stopbits,int parity);
	int UART0_Open(char* port);
	void UART0_Close(int fd);
	int UART0_Recv(int fd, unsigned char *rcv_buf,int data_len);

};




#endif /* SERIAL_ZIGBEE_H_ */
