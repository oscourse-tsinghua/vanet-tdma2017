CROSS_COMPILE=arm-linux-gnueabihf-
zigbee_auto: main.o i2c-gps.o serial-gps.o serial-zigbee.o Ublox.o
	${CROSS_COMPILE}g++ main.o i2c-gps.o serial-gps.o serial-zigbee.o Ublox.o -o zigbee_auto  -lpthread

main.o: main.cpp
	${CROSS_COMPILE}g++ -c main.cpp

i2c-gps.o: 
	${CROSS_COMPILE}g++ -c i2c-gps.cpp
	
serial-gps.o:
	${CROSS_COMPILE}g++ -c serial-gps.cpp

serial-zigbee.o:
	${CROSS_COMPILE}g++ -c serial-zigbee.cpp
	
Ublox.o:
	${CROSS_COMPILE}g++ -c Ublox.cpp
	
clean:
	rm -rf *.o
	rm -rf zigbee_auto
