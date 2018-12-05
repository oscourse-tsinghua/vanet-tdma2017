#ifndef SATMACCOMMON_H
#define SATMACCOMMON_H

//#define PRINT_SLOT_STATUS 1

#define FRAMEADJ_CUT_RATIO_THS 0.5
#define FRAMEADJ_CUT_RATIO_EHS 0.6
#define FRAMEADJ_EXP_RATIO 0.9


//define the length of bit used to signal each field in actual packet
#define BIT_LENGTH_BUSY		2
#define BIT_LENGTH_STI		16
#define BIT_LENGTH_FRAMELEN	4
#define BIT_LENGTH_SLOTNUM	8
#define BIT_LENGTH_PSF		0
#define BIT_LENGTH_COUNT	2
#define BIT_LENGTH_NBCOUNT	5
#define BIT_LENGTH_SLOT_TAG		(BIT_LENGTH_BUSY+BIT_LENGTH_STI + BIT_LENGTH_PSF+BIT_LENGTH_COUNT)

#define SLOT_FREE 				0
//#define SLOT_MINE				2
//#define SLOT_NEIGHBOR_1HOP		2
#define SLOT_1HOP				2
#define SLOT_2HOP 				1
#define SLOT_COLLISION			3

//this struct is used to sign the status of everyslot
struct slot_tag{
	char busy;	//2 bit
	int count_2hop;
	int count_3hop;
	int life_time;
	bool existed;
	int sti;	// 8 bit
	char psf;	// 2 bit
	bool c3hop_flag;
//	bool unsafe;
	bool locker;
	slot_tag(){
		busy=0;
		sti=0;
		psf=0;
		count_2hop = 0;
		count_3hop = 0;
		c3hop_flag = 0;
//		unsafe = 0;
		life_time = 0;
		existed = 0;
		locker = 0;
	}
};

class Frame_info{
public:
	int sti;	// 8 bit
	int index;	// 8 bit
	int remain_time;
	int frame_len;
	int valid_time;
	int recv_slot;
	int type;	//type=0 FI, type=1 短包
	slot_tag *slot_describe;
	Frame_info *next_fi;

	Frame_info(){
		sti = 0;
		index = 0;
		remain_time = 0;
		valid_time = 0;
		recv_slot = -1;
		frame_len=0;
		type = -1;
	}
	Frame_info(int framelen){
		NS_ASSERT( framelen >= 0 );
		sti = 0;
		index = 0;
		remain_time = 0;
		valid_time = 0;
		recv_slot = -1;
		type = -1;
		frame_len = framelen;
		//next_fi = NULL;
		slot_describe = new slot_tag[frame_len];
		NS_ASSERT(slot_describe != NULL);
	}
	~Frame_info(){
		if(slot_describe){
			delete[] slot_describe;
			slot_describe = NULL;
		}
		next_fi = NULL;
	}

};

enum NodeState{
	NODE_INIT = 0,
	NODE_LISTEN = 1,
	NODE_WAIT_REQUEST = 2,
	NODE_REQUEST = 3,
	NODE_WORK_FI = 4,
	NODE_WORK_ADJ = 5,
};

enum SlotState{
	BEGINING = 0x0000,
	FI = 0x0001,
	SAFETY = 0x0002,
	RTS = 0x0003,
	CTS = 0x0004,
	APP = 0x0005,
};
#endif
