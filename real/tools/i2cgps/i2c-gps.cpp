#include <linux/i2c-dev.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdlib.h>
#include "i2c-gps.h"

i2cgps::i2cgps(){
	this->i2cfd_ = -1;
	this->size_ = 0;
	this->gpsdata_ = (u8*)malloc(BUFFER_SIZE);
	this->init();
}
i2cgps::~i2cgps(){
	if(this->i2cfd_ != -1)
		close(this->i2cfd_);
	free(this->gpsdata_);
}

int i2cgps::init(void) {
	int adapter_nr = I2C_DEVICE_FD; /* probably dynamically determined */
	char filename[20];

	snprintf(filename, 19, "/dev/i2c-%d", adapter_nr);
	this->i2cfd_ = open(filename, O_RDWR);
	if (this->i2cfd_ < 0) {
	/* ERROR HANDLING; you can check errno to see what went wrong */
		return -1;
	}

	return 0;
}

int i2cgps::write_gps_config(u8 *data, int size){

	if (ioctl(this->i2cfd_, I2C_SLAVE_FORCE, I2CGPS_I2C_ADDR) < 0) {
		/* ERROR HANDLING; you can check errno to see what went wrong */
		return -1;
	}
	write(this->i2cfd_, data, size);
	return 0;
}

int i2cgps::get_byte_available(){
	unsigned short bytes;
	u8 buf[2];
	bytes = i2c_read(0xfd, buf, 2);
	if(!bytes)
		return -1;
	if(buf[0]==0xff && buf[1]==0xff)
		return -2;
	return ((unsigned short) buf[0] << 8) | buf[1];
}



int i2cgps::get_gps_data2buf(int size){
	int byte2read;
    if (size > BUFFER_SIZE) {
    	byte2read = BUFFER_SIZE;
    } else {
    	byte2read = size;
    }
	return i2c_read(0xff, this->gpsdata_, byte2read);
}

//int i2cgps::read_gps2buf(){
//	if (ioctl(this->i2cfd_, I2C_SLAVE_FORCE, I2CGPS_I2C_ADDR) < 0) {
//		/* ERROR HANDLING; you can check errno to see what went wrong */
//		return -1;
//	}
//
//}
int i2cgps::i2c_wrtie(u8 subaddress, u8 *data, int size){
	char buf[size + 1];
	if (ioctl(this->i2cfd_, I2C_SLAVE_FORCE, I2CGPS_I2C_ADDR) < 0) {
		/* ERROR HANDLING; you can check errno to see what went wrong */
		return -1;
	}
	buf[0] = subaddress;
	if(data != NULL)
		memcpy(buf + 1, data, size);
	write(this->i2cfd_, buf, size + 1);
	return 0;
}

u8* i2cgps::gpsdata_buf() {
	return this->gpsdata_;
}

int i2cgps::gpsdata_buf_size() {
	return this->size_;
}

int i2cgps::i2c_read(u8 subaddress, u8 *buf, int size){

	if (ioctl(this->i2cfd_, I2C_SLAVE_FORCE, I2CGPS_I2C_ADDR) < 0) {
		/* ERROR HANDLING; you can check errno to see what went wrong */
		return -1;
	}
	write(this->i2cfd_, &subaddress, 1);
	if(read(this->i2cfd_, buf, size) == size)
		return size;
	else
		return -2;

}
