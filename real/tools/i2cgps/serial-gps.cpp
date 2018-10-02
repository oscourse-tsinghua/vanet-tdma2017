#include "serial-gps.h"

#include <termios.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdlib.h>


serialGps::serialGps(){
	this->serialfd_ = -1;
	this->size_ = 0;
	this->gpsdata_ = (u8*)malloc(BUFFER_SIZE);
	this->init();
}
serialGps::~serialGps(){
	if(this->serialfd_ != -1)
		close(this->serialfd_);
	free(this->gpsdata_);
}

int serialGps::init(void) {
    int c, res;
    struct termios oldtio, newtio;

    /* Open modem device for reading and writing and not as controlling tty
       because we don't want to get killed if linenoise sends CTRL-C. */
    this->serialfd_ = open(MODEMDEVICE, O_RDONLY | O_NOCTTY );
    if (this->serialfd_ < 0) { perror(MODEMDEVICE); exit(-1); }

    bzero(&newtio, sizeof(newtio)); /* clear struct for new port settings */

    /* BAUDRATE: Set bps rate. You could also use cfsetispeed and cfsetospeed.
       CRTSCTS : output hardware flow control (only used if the cable has
                 all necessary lines. See sect. 7 of Serial-HOWTO)
       CS8     : 8n1 (8bit,no parity,1 stopbit)
       CLOCAL  : local connection, no modem contol
       CREAD   : enable receiving characters */
    newtio.c_cflag = BAUDRATE | CRTSCTS | CS8 | CLOCAL | CREAD;

    /* IGNPAR  : ignore bytes with parity errors
       otherwise make device raw (no other input processing) */
    newtio.c_iflag = IGNPAR;

    /*  Raw output  */
    newtio.c_oflag = 0;

    /* ICANON  : enable canonical input
       disable all echo functionality, and don't send signals to calling program */
    newtio.c_lflag = ICANON;
    /* now clean the modem line and activate the settings for the port */
    tcflush(this->serialfd_, TCIFLUSH);
    tcsetattr(this->serialfd_,TCSANOW,&newtio);

	return 0;
}


int serialGps::get_byte_available(){
	return -1;
}



int serialGps::get_gps_data2buf(){

	return read(this->serialfd_, this->gpsdata_, 255);
}


u8* serialGps::gpsdata_buf() {
	return this->gpsdata_;
}

int serialGps::gpsdata_buf_size() {
	return this->size_;
}
