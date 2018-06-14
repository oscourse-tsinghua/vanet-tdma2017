
/*
 * mac-tdma.h
 * Copyright (C) 1999 by the University of Southern California
 * $Id: mac-tdma.h,v 1.6 2006/02/21 15:20:19 mahrenho Exp $
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.
 *
 *
 * The copyright of this module includes the following
 * linking-with-specific-other-licenses addition:
 *
 * In addition, as a special exception, the copyright holders of
 * this module give you permission to combine (via static or
 * dynamic linking) this module with free software programs or
 * libraries that are released under the GNU LGPL and with code
 * included in the standard release of ns-2 under the Apache 2.0
 * license or under otherwise-compatible licenses with advertising
 * requirements (or modified versions of such code, with unchanged
 * license).  You may copy and distribute such a system following the
 * terms of the GNU GPL for this module and the licenses of the
 * other code concerned, provided that you include the source code of
 * that other code when and as the GNU GPL requires distribution of
 * source code.
 *
 * Note that people who make modified versions of this module
 * are not obligated to grant this special exception for their
 * modified versions; it is their choice whether to do so.  The GNU
 * General Public License gives permission to release a modified
 * version without this exception; this exception also makes it
 * possible to release a modified version which carries forward this
 * exception.
 *
 */

//
// mac-tdma.h
// Ported from mac-tdma.cc by Xuan Chen 
//
// Wujingbang (wjbang@bit.edu.cn)



#ifndef ns_mac_tdma_h
#define ns_mac_tdma_h

// #define DEBUG
//#include <debug.h>
//#define PRINT_FI
//#define PRINT_SLOT_STATUS

#define FRAMEADJ_CUT_RATIO 0.20
#define FRAMEADJ_EXP_RATIO 0.9

#include "marshall.h"
#include <delay.h>
#include <connector.h>
#include <packet.h>
#include <random.h>
#include <arp.h>
#include <ll.h>
#include <mac.h>
#include <math.h>

#define GET_ETHER_TYPE(x)		GET2BYTE((x))
#define SET_ETHER_TYPE(x,y)            {u_int16_t t = (y); STORE2BYTE(x,&t);}

/* We are still using these specs for phy layer---same as 802.11. */
/*
 * IEEE 802.11 Spec, section 15.3.2
 *	- default values for the DSSS PHY MIB
 */
#define DSSS_CWMin			31
#define DSSS_CWMax			1023
#define DSSS_SlotTime			0.000020	// 20us
#define	DSSS_CCATime			0.000015	// 15us
#define DSSS_RxTxTurnaroundTime		0.000005	// 5us
#define DSSS_SIFSTime			0.000010	// 10us
#define DSSS_PreambleLength		144		// 144 bits
#define DSSS_PLCPHeaderLength		48		// 48 bits

class PHY_MIB_TDMA {
public:
	u_int32_t	CWMin;
	u_int32_t	CWMax;
	double		SlotTime;
	double		CCATime;
	double		RxTxTurnaroundTime;
	double		SIFSTime;
	u_int32_t	PreambleLength;
	u_int32_t	PLCPHeaderLength;
};


/* ======================================================================
   Frame Formats
   ====================================================================== */

#define	MAC_ProtocolVersion	0x00

#define MAC_Type_Management	0x00
#define MAC_Type_Control	0x01
#define MAC_Type_Data		0x02
#define MAC_Type_Reserved	0x03

#define MAC_Subtype_RTS		0x0B
#define MAC_Subtype_CTS		0x0C
#define MAC_Subtype_ACK		0x0D
#define MAC_Subtype_Data	0x00
#define MAC_Subtype_BAN		0x01
#define MAC_Subtype_SAFE	0x02


// Max data length allowed in one slot (byte)
#define MAC_TDMA_MAX_DATA_LEN 1500        

// The mode for MacTdma layer's defer timers. */
#define SLOT_SCHE               0
#define SLOT_SEND               1
#define SLOT_RECV               2
#define SLOT_BCAST              3

// Indicate if there is a packet needed to be sent out.
#define NOTHING_TO_SEND         -2
// Indicate if this is the very first time the simulation runs.
#define FIRST_ROUND             -1

// Turn radio on /off
#define ON                       1
#define OFF                      0

/* Quoted from MAC-802.11. */
#define DATA_DURATION           5

/* packet type */
#define PACKET_FI				0
#define PACKET_SAFETY			1
#define PACKET_RTS				2
#define PACKET_CTS				3
#define PACKET_APP				4

/* The total length of the TDMA header */
#define FRAME_CONTROL			2
#define DURATION_ID				2
#define ADRESS_DA				6
#define ADRESS_SA				6
#define ADRESS_SSID				6
#define SEQUENCE_CONTROL		2
#define TDMA_FCS				4

#define TDMA_HDR_LEN 			(FRAME_CONTROL + ADRESS_DA + ADRESS_SA + SEQUENCE_CONTROL)

/* We are using same header structure as 802.11 currently */
struct frame_control_tdma {
	u_char		fc_subtype		: 4;
	u_char		fc_type			: 2;
	u_char		fc_protocol_version	: 2;

	u_char		fc_order		: 1;
	u_char		fc_wep			: 1;
	u_char		fc_more_data		: 1;
	u_char		fc_pwr_mgt		: 1;
	u_char		fc_retry		: 1;
	u_char		fc_more_frag		: 1;
	u_char		fc_from_ds		: 1;
	u_char		fc_to_ds		: 1;
};

struct hdr_mac_tdma {
	struct frame_control_tdma	dh_fc;
	u_int16_t		dh_duration;
	u_char			send_slot;
	u_char			dh_da[ETHER_ADDR_LEN];
	u_char			dh_sa[ETHER_ADDR_LEN];
	u_char			dh_bssid[ETHER_ADDR_LEN];
	u_int16_t		dh_scontrol;
	u_char			dh_body[1]; // XXX Non-ANSI
};

//define the length of bit used to signal each field in actual packet
#define BIT_LENGTH_BUSY		2
#define BIT_LENGTH_STI		16
#define BIT_LENGTH_FRAMELEN	4
#define BIT_LENGTH_SLOTNUM	8
#define BIT_LENGTH_PSF		2
#define BIT_LENGTH_COUNT	8
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
	unsigned char busy;	//2 bit
	unsigned int count_2hop;
	unsigned int count_3hop;
	unsigned int life_time;
	bool existed;
	unsigned int sti;	// 8 bit
	unsigned char psf;	// 2 bit
	bool c3hop_flag;
	bool locker;
	slot_tag(){
		busy=0;
		sti=0;
		psf=0;
		count_2hop = 0;
		count_3hop = 0;
		c3hop_flag = 0;
		life_time = 0;
		existed = 0;
		locker = 0;
	}
};

class Frame_info{
public:
	unsigned int sti;	// 8 bit
	unsigned int index;	// 8 bit
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
		assert( framelen >= 0 );
		sti = 0;
		index = 0;
		remain_time = 0;
		valid_time = 0;
		recv_slot = -1;
		type = -1;
		frame_len = framelen;
		//next_fi = NULL;
		slot_describe = new slot_tag[frame_len];
		assert(slot_describe != NULL);
	}
	~Frame_info(){
		if(slot_describe){
			delete[] slot_describe;
			slot_describe = NULL;
		}
		next_fi = NULL;
	}

	int FI_fade(int time){
		remain_time = remain_time - time;
		return remain_time;
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


#define ETHER_HDR_LEN				\
	((phymib_->PreambleLength >> 3) +	\
	 (phymib_->PLCPHeaderLength >> 3) +	\
	 offsetof(struct hdr_mac_tdma, dh_body[0] ) +	\
	 ETHER_FCS_LEN)

#define DATA_Time(len)	(8 * (len) / bandwidth_)

/* ======================================================================
   The following destination class is used for duplicate detection.
   ====================================================================== */
// We may need it later for caching...
class Host_tdma {
public:
	LIST_ENTRY(Host_tdma) link;
	u_int32_t	index;
	u_int32_t	seqno;
};

/* Timers */
class MacTdma;

class MacTdmaTimer : public Handler {
public:
	MacTdmaTimer(MacTdma* m, double s = 0) : mac(m) {
		busy_ = paused_ = 0; stime = rtime = 0.0; slottime_ = s;
	}

	virtual void handle(Event *e) = 0;

	virtual void start(Packet *p, double time);
	virtual void start(double time);

	virtual void stop(Packet *p);
	virtual void stop(void);

	virtual void pause(void) { assert(0); }
	virtual void resume(void) { assert(0); }

	inline int busy(void) { return busy_; }
	inline int paused(void) { return paused_; }
	inline double slottime(void) { return slottime_; }
	inline double expire(void) {
		return ((stime + rtime) - Scheduler::instance().clock());
	}


protected:
	MacTdma 	*mac;
	int		busy_;
	int		paused_;
	Event		intr;
	double		stime;	// start time
	double		rtime;	// remaining time
	double		slottime_;
};

/* Timer to delay the initialization. */
class DelayInitTimer : public MacTdmaTimer {
public:
	DelayInitTimer(MacTdma *m) : MacTdmaTimer(m) {}
	void	handle(Event *e);
};

/* Timers to schedule transmitting and receiving. */
class SlotTdmaTimer : public MacTdmaTimer {
public:
	SlotTdmaTimer(MacTdma *m) : MacTdmaTimer(m) {}
	void	handle(Event *e);
};

/* Timers to control packet sending and receiving time. */
class RxPktTdmaTimer : public MacTdmaTimer {
public:
	RxPktTdmaTimer(MacTdma *m) : MacTdmaTimer(m) {}

	void	handle(Event *e);
};

class TxPktTdmaTimer : public MacTdmaTimer {
public:
	TxPktTdmaTimer(MacTdma *m) : MacTdmaTimer(m) {}

	void	handle(Event *e);
};

class TdmaBackoffTimer : public MacTdmaTimer {
public:
	TdmaBackoffTimer(MacTdma *m) : MacTdmaTimer(m) , difs_wait(0.0){}

	void	start(int cw, int idle, double difs = 0.0);
	void	handle(Event *e);
	void	pause(void);
	void	resume(double difs);
	void	set_slottime(double s){ this->slottime = s; }
private:
	double	difs_wait;
	double	slottime;
};


struct Packet_list_Node{
	Packet *p;
	Packet_list_Node *next;
	Packet_list_Node(Packet *packet, Packet_list_Node *n){
		p=packet;
		next=n;
	}
};

class Packet_queue {
 public:
	Packet_queue(){
		head=new Packet_list_Node(NULL,NULL);
		tail=head;
		packet_count_=0;
		max_size = 100;
	};
	Packet_queue(int size){
		head=new Packet_list_Node(NULL,NULL);
		tail=head;
		packet_count_=0;
		max_size=size;
	};
	~Packet_queue(){
		Packet_list_Node *p;
		while(tail!=head){
			p=head;
			head=head->next;
			delete p;
		}
		delete head;
	};
	int Enqueue(Packet *p){
		if(packet_count_ < max_size){
			tail->next = new Packet_list_Node(p,NULL);
			tail = tail->next;
			packet_count_++;
			return packet_count_;
		}
		return -1;
	};
	Packet *QueueHead(){
		return head->next->p;
	};
	Packet *Dequeue(){
		Packet *p = NULL;
		Packet_list_Node *first = head->next;
		if(packet_count_ > 0){
			p = first->p;
			head->next = first->next;
			packet_count_--;
			if(packet_count_ == 0){
				tail = head;
			}
			delete first;
		}

		return p;
	};
	bool Isempty(){return (packet_count_ == 0);}
	int Size(){return packet_count_;}

 private:
	Packet_list_Node *head;
	Packet_list_Node *tail;
	int packet_count_;
	int max_size;
};

/* TDMA Mac layer. */
class MacTdma : public Mac {
  friend class DelayInitTimer;
  friend class SlotTdmaTimer;
  friend class TxPktTdmaTimer;
  friend class RxPktTdmaTimer;

 public:
  MacTdma(PHY_MIB_TDMA* p);
  ~MacTdma();
  void		recv(Packet *p, Handler *h);
  inline int	hdr_dst(char* hdr, int dst = -2);
  inline int	hdr_src(char* hdr, int src = -2);
  inline int	hdr_type(char* hdr, u_int16_t type = 0);
  static void 	setvalue(unsigned char value, int bit_len, unsigned char* buffer, int &byte_pos, int &bit_pos);
  int 	get_Frame_len(){return max_slot_num_;};
  unsigned long decode_value(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, unsigned int length);
  
  /* Timer handler */
  void delayInitHandler(Event *e);
  void slotHandler(Event *e);
  void recvHandler(Event *e);
  void sendHandler(Event *e);
  void backoffHandler(Event *e);
  
 protected:
  PHY_MIB_TDMA		*phymib_;
  
  // Both the slot length and max slot num (max node num) can be configged.
  int			slot_packet_len_;
  int           max_node_num_;
  int			random_seed_;
  
 private:
  int command(int argc, const char*const* argv);

  // Do slot scheduling for the active nodes within one cluster.
  void re_schedule();
  void makePreamble();
  void radioSwitch(int i);
  inline int  is_idle(void);

  /* Packet Transmission Functions.*/
  void sendUp(Packet* p);
  void sendDown(Packet* p);
  /* Actually receive data packet when rxTimer times out. */
  void recvPacket(Packet *p);
  /* send as many packets as possible. */
  void sendAll();
  /* Actually send the packet buffered from upwards layers. */
  void sendFI();
  /* Actually send the packet buffered from upwards layers. */
  void sendData();
  /* Actually send the packet buffered from upwards layers. */
  void sendPacket(Packet *&p, int packet_type);

  /*
   * slot_tag and fi handle functions
   */
  /* Determining which slot will be selected as BCH. */
  int determine_BCH(bool strict);
  void show_slot_occupation(void);
  void recvBAN(Packet *p); 
  void recvFI(Packet *p);
  void recvSAFE(Packet *p);
  //void clear_Local_FI(int begin_slot, int end_slot, int slot_num);
  /* Translating the fi_local_ to a FI_packet transmitted */
  Packet*  generate_FI_packet(int slot_num);
  unsigned char* generate_Slot_Tag_Code(slot_tag *st);
  //void update_slot_tag(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, unsigned long long recv_sti);
  //void set_cetain_slot_tag(int index, unsigned char busy,unsigned long long sti, unsigned char psf, unsigned char ptp);
  Packet* generate_FI_packet();
  Packet* generate_BAN_packet();
  Packet* generate_safe_packet();

  //void update_slot_tag(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, unsigned int recv_sti);
  void decode_slot_tag(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, Frame_info *fi);
  Frame_info * get_new_FI(int slot_count);
  void fade_received_fi_list(int time);
  bool isNewNeighbor(unsigned int sid);
  bool isSingle(void);
  void synthesize_fi_list();
  void merge_fi(Frame_info* base, Frame_info* append, Frame_info* decision);
  void clear_FI(Frame_info *fi);
  void clear_others_slot_status();
  void clear_2hop_slot_status();
  void clear_Decision_FI();
  int find_slot(int type, Frame_info* fi);
  int slot_available(int slot_num);

  bool adjust_is_needed(int slot_num);
  void adjFrameLen();
  void merge_local_frame();

  /*
   * exceptional sending or receiving handle functions
   */
  void capture(Packet *p);
  void collision(Packet *p);
  void receive_while_sending(Packet *p);
  void send_while_receiving(Packet *p);

  /* Debugging Functions.*/
  void	discard(Packet *p, const char* why);
  void	trace_pkt(Packet *p);
  void	dump(char* fname);
  void	trace_collision(unsigned long long sti);
  void print_slot_status(void);
  
  void mac_log(Packet *p) {
    logtarget_->recv(p, (Handler*) 0);
  }
  

  inline double TX_Time(Packet *p) {
    double t = DATA_Time((HDR_CMN(p))->size());
    //    printf("<%d>, packet size: %d, tx-time: %f\n", index_, (HDR_CMN(p))->size(), t);
    if(t < 0.0) {
      drop(p, "XXX");
      exit(1);
    }
    return t;
  }
  
  inline int TDMA_Overhead(){
	  int len;
	  len = TDMA_HDR_LEN + TDMA_FCS;
	  return len;
  }

  inline int PHY_TDMA_Overhead(){
	  if(phymib_){
		  int len;
		  len = ((phymib_->PreambleLength)>>3) + ((phymib_->PLCPHeaderLength)>>3) + TDMA_Overhead();
		  return len;
	  }
	  else{
		  return 0;
	  }
  }

  inline u_int16_t usec(double t) {
    u_int16_t us = (u_int16_t)ceil(t *= 1e6);
    return us;
  };

  inline double get_Remain_slottime(){
  	  double time = 0;
  	  double now_time = 0;
  	  now_time = NOW;
  	  time = slot_time_ - (now_time - ((int)((now_time - start_time_)/slot_time_) * slot_time_));
  	  return time;
    }

  /* Timers */
  DelayInitTimer mhDelayInit_;
  SlotTdmaTimer mhSlot_;
  TxPktTdmaTimer mhTxPkt_;
  RxPktTdmaTimer mhRxPkt_;
  TdmaBackoffTimer 	mhBackoff_;

  /* Internal MAC state */
  MacState	rx_state_;	// incoming state (MAC_RECV or MAC_IDLE)
  MacState	tx_state_;	// outgoing state
  
  /* The indicator of the radio. */
  int radio_active_;
  int tx_active_;	// transmitter is ACTIVE
  NsObject*	logtarget_;

  // life time (frames) of a slot
  static int slot_lifetime_frame_s1_;
  static int slot_lifetime_frame_s2_;
  // slot candidate count_3hop threshold step 1 and step 2
  static int c3hop_threshold_s1_;
  static int c3hop_threshold_s2_;
  
  static int adj_free_threshold_;

  static int delay_init_frame_num_;
  static int random_bch_if_single_switch_;
  static int choose_bch_random_switch_;

  // The max num of slot within one frame.
  int max_slot_num_;
  // The time duration for each slot.
  static double slot_time_;
  /* The start time for whole TDMA scheduling. */
  static double start_time_;
  /* Data structure for tdma scheduling. */
  static int active_node_;            // How many nodes needs to be scheduled
  static int *tdma_schedule_;

  int slot_num_;                      // The slot number it's allocated.
  int slot_adj_candidate_;
  int bch_slot_lock_;
  static int *tdma_preamble_;        // The preamble data structure.
  // When slot_count_ = active_nodes_, a new preamble is needed.
  int slot_count_;
  long long total_slot_count_;
  
  // How many packets has been sent out?
  static int tdma_ps_;
  static int tdma_pr_;

  //added variables
  static int frame_len_;
  static int max_frame_len_;
  unsigned int global_sti;
  unsigned int global_psf;

  //slot_tag **fi_list_;
  Frame_info *decision_fi_;
  Frame_info *collected_fi_;
  Frame_info *received_fi_list_;

  NodeState node_state_;
  SlotState slot_state_;
  int backoff_frame_num_;
  int enable;
  int adj_ena_;
  int adj_single_slot_ena_;
  int adj_frame_ena_;
  int adj_frame_lower_bound_;
  int adj_frame_upper_bound_;
  int slot_memory_;
  bool initialed_;
  bool testmode_init_flag_;

  double last_log_time_;
  int collision_count_;
  int localmerge_collision_count_;
  int adj_count_total_;
  int adj_count_success_;
  int request_fail_times;
  int no_avalible_count_;
  int waiting_frame_count;
  int packet_sended;
  int packet_received;
  int frame_count_;
  int continuous_work_fi_;
  int continuous_work_fi_max_;
  int safe_recv_count_;
  int safe_send_count_;

  Packet_queue *app_packet_queue_; //used to buffer packets from upwards layers
  Packet_queue *safety_packet_queue_; //used to buffer packets from upwards layers
  Packet *pktFI_;	//used to buffer FI

//  Packet *pktRTS_;	//used to buffer RTS for SCH
//  Packet *pktCTS_;	//used to buffer CTS for SCH

};


/*
double MacTdma::slot_time_ =0;
double MacTdma::start_time_ = 0;
int MacTdma::active_node_ = 0;
int MacTdma::max_slot_num_ = 0;
int *MacTdma::tdma_schedule_ = NULL;
int *MacTdma::tdma_preamble_ = NULL;

int MacTdma::tdma_ps_ = 0;
int MacTdma::tdma_pr_ = 0;
*/

/* TDMA Mac layer. */

#endif /* __mac_tdma_h__ */
