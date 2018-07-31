#include "string"

using  std::string;

#define I2CGPS_I2C_ADDR 		0x42
#define I2C_DEVICE_FD 		1
#define BUFFER_SIZE			255
typedef unsigned char		u8;

#define MAX_NODES_NUM	2


//string global_nodes_mac[MAX_NODES_NUM] = {
//		"DC:85:DE:7C:64:67",
//		"9C:D2:1E:6F:FD:91"
//};

class i2cgps{
public:
	i2cgps();
	~i2cgps();
	int init(void);
	int write_gps_config(u8 *data, int size);
	//

	u8* gpsdata_buf();
	int gpsdata_buf_size();

//	int get_coordinate(float *buf);
//	float get_altitude(void);
//	int get_UTCtime_hms(int *buf);
	int get_byte_available(void);
	int get_gps_data2buf(int size);

private:
//	Ublox M8_Gps_;
	int i2cfd_;
	u8 *gpsdata_;
	int size_;
	int i2c_wrtie(u8 subaddress, u8 *data, int size);
	int i2c_read(u8 subaddress, u8 *buf, int size);

};
