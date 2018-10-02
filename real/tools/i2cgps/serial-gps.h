/* baudrate settings are defined in <asm/termbits.h>, which is
   included by <termios.h> */
#define BAUDRATE B9600   // Change as needed, keep B

/* change this definition for the correct port */
#define MODEMDEVICE "/dev/ttyPS1" //picozed serial port

#define _POSIX_SOURCE 1 /* POSIX compliant source */

#define FALSE 0
#define TRUE 1
typedef unsigned char		u8;

#define BUFFER_SIZE			255


class serialGps{
public:
	serialGps();
	~serialGps();
	int init(void);

	u8* gpsdata_buf();
	int gpsdata_buf_size();

//	int get_coordinate(float *buf);
//	float get_altitude(void);
//	int get_UTCtime_hms(int *buf);
	int get_byte_available(void);
	int get_gps_data2buf(void);

private:
//	Ublox M8_Gps_;
	int serialfd_;
	u8 *gpsdata_;
	int size_;
};
