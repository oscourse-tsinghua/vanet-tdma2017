// -*-	Mode:C++; c-basic-offset:8; tab-width:8; indent-tabs-mode:t -*-

/*
 * mac-tdma.cc
 * Copyright (C) 1999 by the University of Southern California
 * $Id: mac-tdma.cc,v 1.16 2006/02/22 13:25:43 mahrenho Exp $
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
// $Header: /cvsroot/nsnam/ns-2/mac/mac-tdma.cc,v 1.16 2006/02/22 13:25:43 mahrenho Exp $
//
// Ported from mac-tdma.cc by Xuan Chen 
//
// Wujingbang (wjbang@bit.edu.cn)


#include "delay.h"
#include "connector.h"
#include "packet.h"
#include "random.h"
#include <math.h>

// #define DEBUG

//#include <debug.h>

#include "arp.h"
#include "ll.h"
#include "mac.h"
#include "mac-tdma.h"
#include "wireless-phy.h"
#include "cmu-trace.h"

#include <stddef.h>

#define SET_RX_STATE(x)			\
{					\
	rx_state_ = (x);			\
}

#define SET_TX_STATE(x)				\
{						\
	tx_state_ = (x);				\
}

/* Phy specs from 802.11 */
static PHY_MIB_TDMA PMIB = {
	DSSS_CWMin, DSSS_CWMax, DSSS_SlotTime, DSSS_CCATime,
	DSSS_RxTxTurnaroundTime, DSSS_SIFSTime, DSSS_PreambleLength,
	DSSS_PLCPHeaderLength
};	

/* Timers */
void MacTdmaTimer::start(Packet *p, double time)
{
	Scheduler &s = Scheduler::instance();
	assert(busy_ == 0);
	/*if(busy_ != 0){
		printf("busy_ != 0\n");
	}*/
  
	busy_ = 1;
	paused_ = 0;
	stime = s.clock();
	rtime = time;
	assert(rtime >= 0.0);
  
	s.schedule(this, p, rtime);
}

/* Timers */
void MacTdmaTimer::start(double time)
{
	Scheduler &s = Scheduler::instance();
	assert(busy_ == 0);
	/*if(busy_ != 0){
		printf("busy_ != 0");
	}*/

	busy_ = 1;
	paused_ = 0;
	stime = s.clock();
	rtime = time;
	assert(rtime >= 0.0);

	s.schedule(this, &intr, rtime);
}

void MacTdmaTimer::stop(Packet *p) 
{
	Scheduler &s = Scheduler::instance();
	assert(busy_);
  
	if(paused_ == 0)
		s.cancel((Event *)p);

	// Should free the packet p.
	//Packet::free(p);
  
	busy_ = 0;
	paused_ = 0;
	stime = 0.0;
	rtime = 0.0;
}

void MacTdmaTimer::stop(void)
{
	Scheduler &s = Scheduler::instance();
	assert(busy_);

	if(paused_ == 0)
		s.cancel(&intr);

	// Should free the packet p.
	//Packet::free(p);

	busy_ = 0;
	paused_ = 0;
	stime = 0.0;
	rtime = 0.0;
}

/* Slot timer for TDMA scheduling. */
void SlotTdmaTimer::handle(Event *e)
{       
	busy_ = 0;
	paused_ = 0;
	stime = 0.0;
	rtime = 0.0;
  
	mac->slotHandler(e);
}

/* Receive Timer */
void RxPktTdmaTimer::handle(Event *e) 
{       
	busy_ = 0;
	paused_ = 0;
	stime = 0.0;
	rtime = 0.0;
  
	mac->recvHandler(e);
}

/* Send Timer */
void TxPktTdmaTimer::handle(Event *e) 
{       
	busy_ = 0;
	paused_ = 0;
	stime = 0.0;
	rtime = 0.0;
	
	mac->sendHandler(e);
}

void
TdmaBackoffTimer::handle(Event *e)
{
	busy_ = 0;
	paused_ = 0;
	stime = 0.0;
	rtime = 0.0;
	difs_wait = 0.0;

	mac->backoffHandler(e);
}

void
TdmaBackoffTimer::start(int cw, int idle, double difs)
{
	Scheduler &s = Scheduler::instance();

	assert(busy_ == 0);

	busy_ = 1;
	paused_ = 0;
	stime = s.clock();

	rtime = (/*Random::random() %*/ cw) * this->slottime;
	difs_wait = difs;

	if(idle == 0)
		paused_ = 1;
	else {
		assert(rtime + difs_wait >= 0.0);
		s.schedule(this, &intr, rtime + difs_wait);
	}
}


void
TdmaBackoffTimer::pause()
{
	Scheduler &s = Scheduler::instance();

	//the caculation below make validation pass for linux though it
	// looks dummy

	double st = s.clock();

	double rt = stime + difs_wait;
	double sr = st - rt;
	double mst = this->slottime;

    int slots = int (sr/mst);

	if(slots < 0)
		slots = 0;
	assert(busy_ && ! paused_);

	paused_ = 1;
	rtime -= (slots * this->slottime);

	assert(rtime >= 0.0);

	difs_wait = 0.0;

	s.cancel(&intr);
}


void
TdmaBackoffTimer::resume(double difs)
{
	Scheduler &s = Scheduler::instance();

	assert(busy_ && paused_);

	paused_ = 0;
	stime = s.clock();

	/*
	 * The media should be idle for DIFS time before we start
	 * decrementing the counter, so I add difs time in here.
	 */
	difs_wait = difs;
	/*
#ifdef USE_SLOT_TIME
	ROUND_TIME();
#endif
	*/

	assert(rtime + difs_wait >= 0.0);
       	s.schedule(this, &intr, rtime + difs_wait);
}

/* ======================================================================
   TCL Hooks for the simulator
   ====================================================================== */
static class MacTdmaClass : public TclClass {
public:
	MacTdmaClass() : TclClass("Mac/Tdma") {}
	TclObject* create(int, const char*const*) {
		return (new MacTdma(&PMIB));
	}
} class_mac_tdma;


// Mac Tdma definitions
// Frame format:
// Pamble Slot1 Slot2 Slot3...
MacTdma::MacTdma(PHY_MIB_TDMA* p) :
	Mac(), mhSlot_(this), mhTxPkt_(this), mhRxPkt_(this),mhBackoff_(this){
	/* Global variables setting. */
	// Setup the phy specs.
	phymib_ = p;

	/* Get the parameters of the link (which in bound in mac.cc, 2M by default),
	   the packet length within one TDMA slot (1500 byte by default), 
	   and the max number of nodes (64) in the simulations.*/

	//bind("slot_packet_len_", &slot_packet_len_);
	bind("max_node_num_", &max_node_num_); //这个变量将作为之后对整个网络情况估计，即网络最大有多少个节点
	bind("slot_time_", &slot_time_);
	bind("frame_len_", &frame_len_);
	bind("random_seed_",&random_seed_);
	bind("bandwidth_",&bandwidth_);
	bind("slot_lifetime_frame_", &slot_lifetime_frame_);
	bind("c3hop_threshold_s1_", &c3hop_threshold_s1_);
	bind("c3hop_threshold_s2_", &c3hop_threshold_s2_);

	/* Calsulate the max slot num within on frame from max node num.
	   In the simple case now, they are just equal. 
	*/
	//max_slot_num_ = max_node_num_;
	max_slot_num_ = frame_len_;
	
	/* Much simplified centralized scheduling algorithm for single hop
	   topology, like WLAN etc. 
	*/
	// Initialize the tdma schedule and preamble data structure.
	received_fi_list_= NULL;
	app_packet_queue_= new Packet_queue();
	safety_packet_queue_ = new Packet_queue();

	decision_fi_ = new Frame_info(max_slot_num_);
	decision_fi_->index = this->index_;
	decision_fi_->sti = this->global_sti;

	collected_fi_ = new Frame_info(max_slot_num_);
	collected_fi_->index = this->index_;
	collected_fi_->sti = this->global_sti;


	/* Do each node's initialization. */
	active_node_++; //标记当前是哪个节点。
	global_sti = active_node_; //目前暂时以节点加入的时间顺序作为编号。
	global_psf = 0;

	if (active_node_ > max_node_num_) {
		printf("Too many nodes taking part in the simulations, aborting...\n");
		exit(-1);
	}
    
	// Initial channel / transceiver states. 
	tx_state_ = rx_state_ = MAC_IDLE;
	tx_active_ = 0;
	radio_active_ = 1;

	// Do slot scheduling.
	re_schedule();

	// Can't send anything in the first frame.
	total_slot_count_ = (int)((NOW- start_time_)/slot_time_)-1;// 从0号slot开始计数的话，刚刚完成的那个slot应该是多少号
	slot_count_ = total_slot_count_ % max_slot_num_;
	mhBackoff_.set_slottime(this->phymib_->SIFSTime);

	node_state_ = NODE_INIT;
	slot_state_ = BEGINING;

	collision_count_ = 0;
	request_fail_times = 0;
	waiting_frame_count = 0;

	this->enable=0;

	this->packet_sended = 0;
	this->packet_received =0;

	//Start the Slot timer..
	//这里所做的这些运算目的是：如果一个节点在new的时候不是一个slot刚刚开始的时候，那么他需要首先对齐时钟，等到下一个slot开始再开始处理。
	double wait_time_ = (NOW- start_time_)-((slot_count_+1)*slot_time_);
	mhSlot_.start((Packet *) (& intr_), wait_time_);
}

/* the destruction function */
MacTdma::~MacTdma(){

	Frame_info *current_fi;
	while(received_fi_list_!=NULL){
		current_fi = received_fi_list_;
		received_fi_list_ = current_fi->next_fi;
		delete current_fi;
	}

	if(decision_fi_!=NULL){
		delete decision_fi_;
	}
	if(collected_fi_ != NULL ){
		delete collected_fi_;
	}

	delete safety_packet_queue_;
	delete app_packet_queue_;

}

/* This function is used to pick up a random slot of from those which is free. */
int MacTdma::determine_BCH(bool strict){
	int i=0,chosen_slot=0;
	slot_tag *fi_local_= this->collected_fi_->slot_describe;
	int s1c[1024];
	int s2c[1024];
	int s1c_num = 0, s2c_num = 0;
	for(i=0 ; i < max_slot_num_; i++){
		if(fi_local_[i].busy== SLOT_FREE) {
			if (fi_local_[i].count_3hop < c3hop_threshold_s1_ ){
				s1c[s1c_num++] = i;
			} else if (!strict && fi_local_[i].count_3hop < c3hop_threshold_s2_) {
				s2c[s2c_num++] = i;
			}
		}
	}

	if (s1c_num != 0) {
		chosen_slot = Random::random() % s1c_num;
		return s1c[chosen_slot];
	} else if (s2c_num != 0) {
		chosen_slot = Random::random() % s2c_num;
		return s2c[chosen_slot];
	} else
		return -1;

}

bool MacTdma::adjust_is_needed(int slot_num) {
	slot_tag *fi_collection = this->collected_fi_->slot_describe;
	if (fi_collection[slot_num].count_3hop > c3hop_threshold_s1_)
		return true;
	else
		return false;
}

/* similar to 802.11, no cached node lookup. */
int MacTdma::command(int argc, const char*const* argv)
{
	if (argc == 3) {
		if (strcmp(argv[1], "log-target") == 0) {
			logtarget_ = (NsObject*) TclObject::lookup(argv[2]);
			if(logtarget_ == 0)
				return TCL_ERROR;
			return TCL_OK;
		}
	}
	return Mac::command(argc, argv);
}


/* ======================================================================
   Debugging Routines
   ====================================================================== */
void MacTdma::trace_pkt(Packet *p) 
{
	struct hdr_cmn *ch = HDR_CMN(p);
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);
	u_int16_t *t = (u_int16_t*) &dh->dh_fc;

	fprintf(stderr, "\t[ %2x %2x %2x %2x ] %x %s %d\n",
		*t, dh->dh_duration,
		ETHER_ADDR(dh->dh_da), ETHER_ADDR(dh->dh_sa),
		index_, packet_info.name(ch->ptype()), ch->size());
}

void MacTdma::trace_collision(unsigned long long sti){
	fprintf(stderr, "\n collision happen at --- node %lld --- time: %2.9f )\n", sti,
			Scheduler::instance().clock());

}

void MacTdma::dump(char *fname)
{
	fprintf(stderr, "\n%s --- (INDEX: %d, time: %2.9f)\n", fname, 
		index_, Scheduler::instance().clock());
	
	fprintf(stderr, "\ttx_state_: %x, rx_state_: %x, idle: %d\n", 
		tx_state_, rx_state_, is_idle());
	fprintf(stderr, "\tpktTx_: %lx, pktRx_: %lx, callback: %lx\n", 
		(long) pktTx_, (long) pktRx_, (long) callback_);
}


/* ======================================================================
   Packet Headers Routines
   ====================================================================== */
int MacTdma::hdr_dst(char* hdr, int dst )
{
	struct hdr_mac_tdma *dh = (struct hdr_mac_tdma*) hdr;
	if(dst > -2)
		STORE4BYTE(&dst, (dh->dh_da));
	return ETHER_ADDR(dh->dh_da);
}

int MacTdma::hdr_src(char* hdr, int src )
{
	struct hdr_mac_tdma *dh = (struct hdr_mac_tdma*) hdr;
	if(src > -2)
		STORE4BYTE(&src, (dh->dh_sa));
  
	return ETHER_ADDR(dh->dh_sa);
}

int MacTdma::hdr_type(char* hdr, u_int16_t type) 
{
	struct hdr_mac_tdma *dh = (struct hdr_mac_tdma*) hdr;
	if(type)
		STORE2BYTE(&type,(dh->dh_body));
	return GET2BYTE(dh->dh_body);
}

/* Test if the channel is idle. */
int MacTdma::is_idle() {
	if(rx_state_ != MAC_IDLE)
		return 0;
	if(tx_state_ != MAC_IDLE)
		return 0;
	return 1;
}

/* Do the slot re-scheduling:
   The idea of postpone the slot scheduling for one slot time may be useful.
*/
void MacTdma::re_schedule() {
	//static int slot_pointer = 0;
	// Record the start time of the new schedule

	//在第一个节点被初始化的时候设定系统的开始时间，之后的节点都要以这个时间为准
	if (active_node_ == 1 ){
		start_time_ = NOW;
		Random::seed(this->random_seed_);
	}

	/* Seperate slot_num_ and the node id: 
	   we may have flexibility as node number changes.
	*/
	//slot_num_ = slot_pointer++;
	//tdma_schedule_[slot_num_] = (char) index_;
}

/* To handle incoming packet. */
void MacTdma::recv(Packet* p, Handler* h) {
	struct hdr_cmn *ch = HDR_CMN(p);

	//这是我添加的内容因为现在接收到的包都是error的。
	if (ch->error() == 1) {
		//printf("<%d>, received a error packet!\n", index_);
		ch->error() = 0;
	};
	
	/* Incoming packets from phy layer, send UP to ll layer. 
	   Now, it is in receiving mode. 
	*/
	if (ch->direction() == hdr_cmn::UP) {
		sendUp(p);
		//printf("<%d> packet recved: %d\n", index_, tdma_pr_++);
		return;
	}
	
	/* Packets coming down from ll layer (from ifq actually),
	   send them to phy layer. 
	   Now, it is in transmitting mode. */

	callback_ = h;
	state(MAC_SEND);
	sendDown(p);
	//printf("<%d> packet sent down: %d\n", index_, tdma_ps_++);
}

/*
 * 本函数进行的主要工作是在收到一个包之后对是接收进行判定，
 * 主要的内容包括：天线是否打开，是否正在发送，是否正在接收三项，
 * 对应与每一项应该有相应的处理方式
 */
void MacTdma::sendUp(Packet* p) 
{
	struct hdr_cmn *ch = HDR_CMN(p);

	// Since we can't really turn the radio off at lower level,
	// we just discard the packet.
	if (!radio_active_) {
		free(p);
		printf("<%d>, %f, I am sleeping...\n", index_, NOW);
		return;
	}

	/* Can't receive while transmitting.*/
	if (tx_state_ && ch->error() == 0) {
		//printf("<%d>, can't receive while transmitting!\n", index_);
		//ch->error() = 1;
		receive_while_sending(p);
		return;
	};

	/* Detect if there is any collision happened. should not happen...?*/
	if (rx_state_ == MAC_IDLE) {
		SET_RX_STATE(MAC_RECV);     // Change the state to recv.
		pktRx_ = p;                 // Save the packet for timer reference.

		/* Schedule the reception of this packet, 
		   since we just see the packet header. */
		double rtime = TX_Time(p);
		assert(rtime >= 0);

		/* Start the timer for receiving, will end when receiving finishes. */
		mhRxPkt_.start(p, rtime);
	}
	else {
		/*
		 *  If the power of the incoming packet is smaller than the
		 *  power of the packet currently being received by at least
		 *  the capture threshold, then we ignore the new packet.
		 */
		if(pktRx_->txinfo_.RxPr / p->txinfo_.RxPr >= p->txinfo_.CPThresh) {
			capture(p);
		} else {
			collision(p);
		}
		//printf("<%d>, receiving, but the channel is not idle....???\n", index_);
	}
}

void
MacTdma::discard(Packet *p, const char* why)
{
	struct hdr_cmn *ch = HDR_CMN(p);
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);

	/* if the received packet contains errors, a real MAC layer couldn't
	   necessarily read any data from it, so we just toss it now */
	if(ch->error() != 0) {
		Packet::free(p);
		return;
	}

	switch(dh->dh_fc.fc_type) {
	case MAC_Type_Management:
		switch(dh->dh_fc.fc_subtype) {
			case MAC_Subtype_Data:
				if((u_int32_t)ETHER_ADDR(dh->dh_da) == (u_int32_t)index_
						||(u_int32_t)ETHER_ADDR(dh->dh_sa) == (u_int32_t)index_
						||((u_int32_t)ETHER_ADDR(dh->dh_da) == MAC_BROADCAST && dh->dh_fc.fc_to_ds == 0)) {
					drop(p,why);
					return;
				}
				break;
			default:
				fprintf(stderr, "invalid MAC Data subtype\n");
				exit(1);
			}
		break;
	case MAC_Type_Control:
		switch(dh->dh_fc.fc_subtype) {
			case MAC_Subtype_RTS:
				 if((u_int32_t)ETHER_ADDR(dh->dh_sa) ==  (u_int32_t)index_) {
					drop(p, why);
					return;
				}
				/* fall through - if necessary */
			case MAC_Subtype_CTS:
			case MAC_Subtype_ACK:
				if((u_int32_t)ETHER_ADDR(dh->dh_da) == (u_int32_t)index_) {
					drop(p, why);
					return;
				}
				break;
			default:
				fprintf(stderr, "invalid MAC Control subtype\n");
				exit(1);
			}
		break;
	case MAC_Type_Data:
		switch(dh->dh_fc.fc_subtype) {
			case MAC_Subtype_Data:
				if((u_int32_t)ETHER_ADDR(dh->dh_da) == (u_int32_t)index_
						||(u_int32_t)ETHER_ADDR(dh->dh_sa) == (u_int32_t)index_
						||((u_int32_t)ETHER_ADDR(dh->dh_da) == MAC_BROADCAST && dh->dh_fc.fc_to_ds == 0)) {
					drop(p,why);
					return;
				}
				break;
			default:
				fprintf(stderr, "invalid MAC Data subtype\n");
				exit(1);
		}
		break;
	default:
		fprintf(stderr, "invalid MAC type (%x)\n", dh->dh_fc.fc_type);
		trace_pkt(p);
		exit(1);
	}
	Packet::free(p);
}

void
MacTdma::capture(Packet *p)
{
	/*
	 * Update the NAV so that this does not screw
	 * up carrier sense.
	 */
	//set_nav(usec(phymib_.getEIFS() + txtime(p)));
	Packet::free(p);
}

/*
 * This function is used to handle the collision between receiving packets
 */
void
MacTdma::collision(Packet *p)
{
	switch(rx_state_) {
		case MAC_BUSY:
			assert(pktRx_);
			assert(mhRxPkt_.busy());
			/*看这来过那个数据包哪个会现先结束*/
			if(TX_Time(p) > mhRxPkt_.expire()) {
				mhRxPkt_.stop(pktRx_);
				discard(pktRx_, DROP_MAC_BUSY);

				pktRx_ = p;
				SET_RX_STATE(MAC_COLL);
				mhRxPkt_.start(pktRx_,TX_Time(pktRx_));
			}
			else {
				discard(p, DROP_MAC_COLLISION);
			}
			break;
		case MAC_RECV:
			SET_RX_STATE(MAC_COLL);
			assert(pktRx_);
			assert(mhRxPkt_.busy());
			double newptime,remaintime;
			newptime= TX_Time(p);
			remaintime = mhRxPkt_.expire();
			if(TX_Time(p) > mhRxPkt_.expire()) {
				mhRxPkt_.stop(pktRx_);
				discard(pktRx_, DROP_MAC_COLLISION);

				pktRx_ = p;
				mhRxPkt_.start(pktRx_,TX_Time(pktRx_));
			}
			else {
				discard(p, DROP_MAC_COLLISION);
			}
			break;
		case MAC_COLL:
			assert(pktRx_);
			assert(mhRxPkt_.busy());
			/*
			 *  Since a collision has occurred, figure out
			 *  which packet that caused the collision will
			 *  "last" the longest.  Make this packet,
			 *  pktRx_ and reset the Recv Timer if necessary.
			 */
			if(TX_Time(p) > mhRxPkt_.expire()) {
				mhRxPkt_.stop(pktRx_);
				discard(pktRx_, DROP_MAC_COLLISION);

				pktRx_ = p;
				mhRxPkt_.start(pktRx_,TX_Time(pktRx_));
			}
			else {
				discard(p, DROP_MAC_COLLISION);
			}
			break;
		default:
			assert(0);
	}
}

/*
 * This function is to handle the situation that a packet arrived when transmitting has begin
 */
void
MacTdma::receive_while_sending(Packet *p)
{
	assert(tx_state_);

	switch(rx_state_) {
		case MAC_COLL:
			assert(pktRx_);
			assert(mhRxPkt_.busy());
			/*
			*  Since a collision has occurred, figure out
			 *  which packet that caused the collision will
			*  "last" the longest.  Make this packet,
			*  pktRx_ and reset the Recv Timer if necessary.
			*/
			if(TX_Time(p) > mhRxPkt_.expire()) {
				mhRxPkt_.stop(pktRx_);
				discard(pktRx_, DROP_MAC_COLLISION);

				pktRx_ = p;
				SET_RX_STATE(MAC_BUSY);
				mhRxPkt_.start(pktRx_,TX_Time(pktRx_));
			}
			else {
				discard(p, DROP_MAC_BUSY);
			}
			break;
		case MAC_IDLE:
			SET_RX_STATE(MAC_BUSY);
			/* fall through */
		case MAC_BUSY:
			/*  Since a busy collision has occurred, signal with MAC_BUSY*/
			if(mhRxPkt_.busy()){
				if(TX_Time(p) > mhRxPkt_.expire()) {
					mhRxPkt_.stop(pktRx_);
					discard(pktRx_, DROP_MAC_BUSY);// Since a tx has begin , is must be busy not collision
					pktRx_ = p;
					mhRxPkt_.start(pktRx_,TX_Time(pktRx_));
				}
				else {
					discard(p, DROP_MAC_COLLISION);
				}
			}
			else{
				pktRx_ = p;
				mhRxPkt_.start(pktRx_,TX_Time(pktRx_));
			}
			break;
		default:
			assert(0);
	}
}

/*
 * This function is to handle the situation that packet need to send when receiving has not finished
 */
void
MacTdma::send_while_receiving(Packet *p)
{
	switch(rx_state_) {
		case MAC_COLL:
			break;
		case MAC_RECV:
			SET_RX_STATE(MAC_BUSY);
			/* fall through */
		case MAC_BUSY:
			break;
		default:
			assert(0);
	}
}

/* Actually receive data packet when RxPktTimer times out. */
void MacTdma::recvPacket(Packet *p){
	/*Adjust the MAC packet size: strip off the mac header.*/
	struct hdr_cmn *ch = HDR_CMN(p);
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);

	if (dh->dh_fc.fc_type == MAC_Type_Management){
		//迭代信道状态
		if(dh->dh_fc.fc_subtype == MAC_Subtype_Data){
			recvFI(p);
		}
		else if(dh->dh_fc.fc_subtype == MAC_Subtype_BAN){
			recvBAN(p);
		}
		uptarget_->recv(p,(Handler*)0);
		return;
	} else if(dh->dh_fc.fc_type == MAC_Type_Data){
		//直接上传到上层
		ch->size()-= ETHER_HDR_LEN;
		ch->num_forwards()+=1;

		this->packet_received ++;
		/*printf("Node<%d>: Receive %d packets from up layer, send %d packets out! Receive %d packets from other node!\n"
						,this->sti
						,packet_sended
						,packet_sended-safety_packet_queue_->Size()
						,packet_received);*/
		uptarget_->recv(p,(Handler*)0);
		return;
	} else if(dh->dh_fc.fc_type == MAC_Type_Control){
		//暂时没有处理
		uptarget_->recv(p,(Handler*)0);
		return;
	}
}

/*
 * allocate a new fi and add insert in the head of received_fi_list;
 */
Frame_info * MacTdma::get_new_FI(int slot_count){
	Frame_info *newFI= new Frame_info(slot_count);
	newFI->next_fi = this->received_fi_list_;
	received_fi_list_ = newFI;
	return newFI;
}

/*
 * reduce the remain_time of each of received_fi_list_
 * if the argument time ==0 then clear the received_fi_list_;
 */
void MacTdma::fade_received_fi_list(int time){
	Frame_info *current, *previous;
	current=this->received_fi_list_;
	previous=NULL;

	while(current != NULL){
		current->remain_time -= time;
		if(current->remain_time <= 0 || time == 0){
			if(previous == NULL){
				this->received_fi_list_ = current->next_fi;
				delete current;
				current = this->received_fi_list_;
				continue;
			}
			else{
				previous->next_fi= current->next_fi;
				delete current;
				current = previous->next_fi;
				continue;
			}
		}
		else{
			previous = current;
			current = current->next_fi;
		}
	}
}

void MacTdma::recvBAN(Packet *p) {
	unsigned int bit_pos=7, byte_pos=0;
	unsigned long value=0;
	unsigned int i=0;
	unsigned int recv_sti, recv_psf, recv_target_slotnum;
	slot_tag *fi_collection = this->collected_fi_->slot_describe;
	
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);
	unsigned char* buffer = p->accessdata();

	recv_sti = (unsigned int)this->decode_value(buffer,byte_pos,bit_pos,BIT_LENGTH_STI);
	//psf
	recv_psf = (unsigned int)this->decode_value(buffer,byte_pos,bit_pos,BIT_LENGTH_PSF);
	//target slot number
	recv_target_slotnum = (unsigned int)this->decode_value(buffer,byte_pos,bit_pos,BIT_LENGTH_SLOTNUM);
	if (recv_target_slotnum != slot_count_)
		printf("recvBAN: recv_target_slotnum != slot_count_ !!!!\n");

	//清除对应时隙的状态。
	fi_collection[recv_target_slotnum].busy = SLOT_FREE;
	fi_collection[recv_target_slotnum].sti = 0;
	fi_collection[recv_target_slotnum].count_2hop = 0;
	fi_collection[recv_target_slotnum].count_3hop = 0;
	fi_collection[recv_target_slotnum].psf = 0;
	fi_collection[recv_target_slotnum].c3hop_flag = 0;
	fi_collection[recv_target_slotnum].life_time = 0;
	fi_collection[recv_target_slotnum].locker = 0; // there is no need to lock it beacuse T20 rule.

	return;

}

/**
 * 把收到的FI包解序列化后存到received_fi_list_中。
 */
void MacTdma::recvFI(Packet *p){
	unsigned int bit_pos=7, byte_pos=0;
	unsigned long value=0;
	unsigned int i=0;
	//unsigned int bit_remain,index;
	Frame_info *fi_recv;
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);
	unsigned char* buffer = p->accessdata();

	/*
	if(this->sti>350){
		printf("my sti = %d \n",sti);
	}*/

	value=this->decode_value(buffer,byte_pos,bit_pos,BIT_LENGTH_STI);
	fi_recv = this->get_new_FI(max_slot_num_);
	fi_recv->sti = (unsigned int)value;
	fi_recv->index = (u_int32_t)ETHER_ADDR(dh->dh_sa);
	fi_recv->recv_slot = this->slot_count_;
	//fi_recv->type = TYPE_FI;

	fi_recv->valid_time = this->max_slot_num_;
	fi_recv->remain_time = fi_recv->valid_time;


	for(i=0; i<(unsigned int)max_slot_num_; i++){
		decode_slot_tag(buffer, byte_pos, bit_pos, i, fi_recv);
	}

	return;
}

void MacTdma::decode_slot_tag(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, Frame_info *fi){
	unsigned long value=0;

	slot_tag* fi_local=fi->slot_describe;
	assert(bit_pos >= 0);
	//busy
	value=this->decode_value(buffer,byte_pos,bit_pos,BIT_LENGTH_BUSY);
	fi_local[slot_pos].busy = (unsigned char)value;

	//sti
	value=this->decode_value(buffer,byte_pos,bit_pos,BIT_LENGTH_STI);
	fi_local[slot_pos].sti = (unsigned int)value;

	//psf
	value=this->decode_value(buffer,byte_pos,bit_pos,BIT_LENGTH_PSF);
	fi_local[slot_pos].psf = (unsigned int)value;

	return;
}

void MacTdma::merge_fi(Frame_info* base, Frame_info* append, Frame_info* decision){
	int count=0;
	slot_tag *fi_local_ = base->slot_describe;
	slot_tag *fi_append = append->slot_describe;
	slot_tag recv_tag;

	//遍历每一个时隙
	for (count=0; count < max_slot_num_; count++){
		if (fi_local_[count].locker == 1)
			continue;
		
		//merge the recv_tag to fi_local_[slot_pos]
		recv_tag = fi_append[count];
		//我自己的时隙
		if (fi_local_[count].busy == SLOT_1HOP && fi_local_[count].sti == global_sti) {
			if (fi_local_[count].sti != recv_tag.sti) {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						if (recv_tag.psf > fi_local_[count].psf) {
							fi_local_[count].life_time = slot_lifetime_frame_;
							fi_local_[count].sti = recv_tag.sti;
							fi_local_[count].count_2hop ++;
							fi_local_[count].count_3hop += recv_tag.count_2hop;
							if (recv_tag.sti == append->sti) { //FI发送者是该时隙的占有者
								fi_local_[count].busy = SLOT_1HOP;
							} else {
								fi_local_[count].busy = SLOT_2HOP;						
							}
						}
						break;
					case SLOT_2HOP:
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_FREE:
						break;
				}
			} else {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_2HOP:
					case SLOT_FREE:
						break;
				}
			}
		}else if (fi_local_[count].busy == SLOT_1HOP && fi_local_[count].sti != global_sti) {//直接邻居占用
			if (fi_local_[count].sti != recv_tag.sti) {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						if (recv_tag.sti == append->sti) { //FI发送者是该时隙的占有者
							if (recv_tag.psf > fi_local_[count].psf) {
								fi_local_[count].life_time = slot_lifetime_frame_;
								fi_local_[count].sti = recv_tag.sti;
								fi_local_[count].count_2hop ++;
								fi_local_[count].count_3hop += recv_tag.count_2hop;
								fi_local_[count].busy = SLOT_1HOP;
							}
						} else {
							fi_local_[count].count_2hop ++;
							fi_local_[count].count_3hop += recv_tag.count_2hop;
						}
						break;
					case SLOT_2HOP:
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_FREE:
						break;
				}
			} else {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						if (recv_tag.sti == append->sti) { //FI发送者是该时隙的占有者
							fi_local_[count].life_time = slot_lifetime_frame_;
							fi_local_[count].count_2hop ++;
							fi_local_[count].count_3hop += recv_tag.count_2hop;
						} else {
							// do nothing.
						}
						break;
					case SLOT_2HOP:
					case SLOT_FREE:
						break;
				}
			}
		}else if (fi_local_[count].busy == SLOT_2HOP) {//两跳邻居占用
			if (fi_local_[count].sti != recv_tag.sti) {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						fi_local_[count].count_2hop ++;
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_2HOP:
					case SLOT_FREE:
						break;
				}	
			} else {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						fi_local_[count].life_time = slot_lifetime_frame_;
						fi_local_[count].busy = SLOT_1HOP;
						
						fi_local_[count].count_2hop ++;
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_2HOP:
						fi_local_[count].life_time = slot_lifetime_frame_;
						if (fi_local_[count].c3hop_flag == 0) {
							fi_local_[count].c3hop_flag = 1;
							fi_local_[count].count_2hop ++;
							fi_local_[count].count_3hop += recv_tag.count_2hop;
						}	
						break;
					case SLOT_FREE:
						break;
				}				
			}
		} else { //空闲时隙
			if (fi_local_[count].sti != recv_tag.sti) {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						fi_local_[count].life_time = slot_lifetime_frame_;
						fi_local_[count].sti = recv_tag.sti;
						fi_local_[count].count_2hop = 1;
						fi_local_[count].count_3hop = recv_tag.count_2hop;
						if (recv_tag.sti == append->sti) { //FI发送者是该时隙的占有者
							fi_local_[count].busy = SLOT_1HOP;
						} else {
							fi_local_[count].busy = SLOT_2HOP;						
						}
						break;
					case SLOT_2HOP:
					case SLOT_FREE:
						break;
				}	
			}
		}
	}
	return;
}

void MacTdma::synthesize_fi_list(){
	Frame_info * processing_fi = received_fi_list_;
	int count;
	slot_tag *fi_local = this->collected_fi_->slot_describe;
	for (count=0; count < max_slot_num_; count++){
		if (fi_local[count].locker)
			fi_local[count].locker = 0; //the locker must be locked in the last frame.
		
		if (fi_local[count].life_time > 1)
			fi_local[count].life_time--;
		else if (fi_local[count].life_time == 1) {
			fi_local[count].busy = SLOT_FREE;
			fi_local[count].sti = 0;
			fi_local[count].count_2hop = 0;
			fi_local[count].count_3hop = 0;
			fi_local[count].psf = 0;
			fi_local[count].c3hop_flag = 0;
			fi_local[count].life_time = 0;
			fi_local[count].locker = 1; // lock the status for one frame.
		}
	}
	
	while(processing_fi != NULL){
		merge_fi(this->collected_fi_, processing_fi, this->decision_fi_);
		processing_fi = processing_fi->next_fi;
	}

}
/* Send packet down to the physical layer. 
   Need to calculate a certain time slot for transmission. */
void MacTdma::sendDown(Packet* p) {
	//u_int32_t dst, src;
  
	struct hdr_cmn* ch = HDR_CMN(p);
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);

	/* Update the MAC header, same as 802.11 */
	ch->size() += ETHER_HDR_LEN;

	dh->dh_fc.fc_protocol_version = MAC_ProtocolVersion;
	dh->dh_fc.fc_type       = MAC_Type_Data;
	dh->dh_fc.fc_subtype    = MAC_Subtype_Data;
	
	dh->dh_fc.fc_to_ds      = 0;
	dh->dh_fc.fc_from_ds    = 0;
	dh->dh_fc.fc_more_frag  = 0;
	dh->dh_fc.fc_retry      = 0;
	dh->dh_fc.fc_pwr_mgt    = 0;
	dh->dh_fc.fc_more_data  = 0;
	dh->dh_fc.fc_wep        = 0;
	dh->dh_fc.fc_order      = 0;

	if((u_int32_t)ETHER_ADDR(dh->dh_da) != MAC_BROADCAST)
		dh->dh_duration = DATA_DURATION; //这里的时间可能要重新计算
	else
		dh->dh_duration = 0;

	//dst = ETHER_ADDR(dh->dh_da);
	//src = ETHER_ADDR(dh->dh_sa);
	ch->txtime() = TX_Time(p);
	if(ch->ptype_ == PT_CBR){
		//printf("ch->ptype_ == PT_CBR");
		u_int32_t dst = MAC_BROADCAST;
		STORE4BYTE(&dst, (dh->dh_da));
	}

	/* buffer the packet to be sent. */
	if(safety_packet_queue_->Enqueue(p) >=0 ){
		this->packet_sended ++;
	}
}

void MacTdma::setvalue(unsigned char value,
		int bit_len, unsigned char* buffer, int &byte_pos, int &bit_pos){

	int shift=0,field_length=0,mode=0,i=0,bit_remain;
	int index;

	index = byte_pos;
	field_length = bit_len;
	bit_remain = bit_pos+1;

	assert(bit_pos >= 0);
	assert(bit_len >= 1);

	while(true){

		mode = 0;

		if(bit_remain==0){
			bit_remain=8;
			index++;
		}

		if(field_length<=0)	break;

		if (bit_remain >= field_length){
			shift = bit_remain-field_length;
			for(i=0; i<field_length; i++){
				mode += pow(2,i);
			}
			bit_remain = shift;
			field_length=0;
		}
		else{
			shift = 0;
			for(i=0; i<bit_remain; i++){
				mode += pow(2,i);
			}
			field_length -= bit_remain;
			bit_remain = 0;
		}
		buffer[index] |= (( value >> field_length ) & mode ) << shift;
	}

	byte_pos=index;
	bit_pos = bit_remain-1;
}

/* This function is translate a slot_tag to bit code transmitted.
 * The length depends on the BIT_LENGTH defined in "mac-tadma.h". */
unsigned char* generate_Slot_Tag_Code(slot_tag *st){

	int bit_pos=7, byte_pos=0, tag_size=0,i;
	int field_length=0;
	unsigned char buffer=0;

	tag_size= BIT_LENGTH_SLOT_TAG / 8;
	if((BIT_LENGTH_SLOT_TAG %8) != 0 ){
		tag_size++;
	}
	unsigned char* code = new unsigned char[tag_size];
	// 将buffer全部清零
	for(i=0;i<tag_size;i++){
		code[i]=0;
	}

	//BUSY
	if (st->busy == 0 || st->busy == 3 || st->busy == 2 ){
		buffer=(unsigned char)0;
		MacTdma::setvalue(buffer, BIT_LENGTH_SLOT_TAG, code, byte_pos, bit_pos);
	}
	else{
		buffer=(unsigned char)1;
		MacTdma::setvalue(buffer, BIT_LENGTH_SLOT_TAG, code, byte_pos, bit_pos);
	}

	//STI
	field_length = BIT_LENGTH_STI/8 ;

	for(i = field_length ; i>0 ; i-- ){
		buffer =(unsigned char)(st->sti)>>(8*i);
		MacTdma::setvalue(buffer, 8, code, byte_pos, bit_pos);
	}
	if ( BIT_LENGTH_STI%8 != 0 ){
		buffer= (unsigned char)(st->sti);
		MacTdma::setvalue(buffer, BIT_LENGTH_STI%8, code, byte_pos, bit_pos);
	}

	//PSF
	MacTdma::setvalue(st->psf, BIT_LENGTH_PSF, code, byte_pos, bit_pos);

	return code;
}

/*
 * clear the slot_tag from begin_slot to end_slot, including begin_slot and end_slot


void MacTdma::clear_Local_FI(int begin_slot, int end_slot, int slot_num){
	int head = begin_slot;
	int tail = end_slot;
	int i = 0;
	slot_tag *fi_local_= fi_list_[slot_num];

	if(head >= tail){
		for(i=head; i< max_slot_num_; i++){
			fi_local_[i].busy=SLOT_FREE;
			fi_local_[i].sti=0;
			fi_local_[i].psf=0;
			fi_local_[i].ptp=0;
		}
		head=0;
	}
	for(i=head; i<=tail; i++){
		fi_local_[i].busy=SLOT_FREE;
		fi_local_[i].sti=0;
		fi_local_[i].psf=0;
		fi_local_[i].ptp=0;
	}

	return;
} */

unsigned long MacTdma::decode_value(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, unsigned int length){
	unsigned long mode = 0;
	unsigned long value=0;
	unsigned int i=0,j=0,field_length;
	unsigned int bit_remain,index,shift;

	index = byte_pos;
	bit_remain = bit_pos+1;
	//field_length = length;

	field_length = length % 8;
	if(field_length !=0){//  should first read the remaining field_length bits
		while(field_length>0){
			if (bit_remain >= field_length){
				mode = 0;
				shift = bit_remain-field_length;
				for(j=0; j< field_length ; j++){
					mode += pow(2,j);
				}
				value =  value | ((buffer[index] >> shift ) & mode);
				bit_remain -= field_length;
				if(bit_remain == 0){
					bit_remain =8;
					index++;
				}
				field_length = 0;
			}
			else{
				mode=0;
				shift = 0;
				for(j=0; j< bit_remain ; j++){
					mode += pow(2,j);
				}
				value = value | (( buffer[index] >> shift ) & mode ) << (8-bit_remain);
				field_length = field_length-bit_remain;
				bit_remain=8;
				index++;
			}
		}
	}
	for(i=0 ; i< length/8 ; i++){
		field_length=8;
		value = value << 8;
		while(field_length>0){
			if (bit_remain >= field_length){
				mode = 0;
				shift = bit_remain-field_length;
				for(j=0; j< field_length ; j++){
					mode += pow(2,j);
				}
				value = value | ((buffer[index] >> shift ) & mode);
				bit_remain -= field_length;
				if(bit_remain == 0){
					bit_remain =8;
					index++;
				}
				field_length = 0;
			}
			else{
				mode=0;
				shift = 0;
				for(j=0; j< bit_remain ; j++){
					mode += pow(2,j);
				}
				value = value | (( buffer[index] >> shift ) & mode ) << (8-bit_remain);
				field_length = field_length-bit_remain;
				bit_remain=8;
				index++;
			}
		}
	}

	byte_pos = index;
	bit_pos = bit_remain-1;

	return value;
}

Packet* MacTdma::generate_BAN_packet(){
	Packet* p = Packet::alloc();
	struct hdr_cmn* ch = HDR_CMN(p);
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);

	int bit_pos=7, byte_pos=0, fi_size=0;
	int field_length=0,i=0;
	unsigned char buffer=0;
	u_int32_t dst = MAC_BROADCAST;
	unsigned int my_sti = this->global_sti;

	fi_size= (BIT_LENGTH_SLOT_TAG * max_slot_num_ + BIT_LENGTH_STI)/8;
	if(((BIT_LENGTH_SLOT_TAG * max_slot_num_ + BIT_LENGTH_STI) %8) != 0 ){
		fi_size++;
	}
	unsigned char* code = new unsigned char[fi_size];
	for(i=0;i<fi_size;i++){
		code[i]=0;// 将buffer全部清零
	}

	field_length = BIT_LENGTH_STI/8 ;

	if ( BIT_LENGTH_STI%8 != 0 ){
		buffer = (unsigned char)(global_sti>>( 8* field_length ));
		setvalue(buffer, BIT_LENGTH_STI%8, code, byte_pos, bit_pos);
	}

	for(int j = field_length-1 ; j >= 0 ; j-- ){
		buffer = (unsigned char)(global_sti>>(8*j));
		setvalue(buffer, 8, code, byte_pos, bit_pos);
	}
	//PSF
	buffer = (unsigned char)global_psf;
	setvalue(buffer, BIT_LENGTH_PSF, code, byte_pos, bit_pos);
	//Target slot number.
	buffer = (unsigned char)slot_count_;
	setvalue(buffer, BIT_LENGTH_SLOTNUM, code, byte_pos, bit_pos);
	p->setdata(fi_size,code);

	ch->uid() = 0;
	ch->ptype() = PT_TDMA;
	ch->size() = fi_size + PHY_TDMA_Overhead();
	ch->iface() = -2;
	ch->error() = 0;
	ch->txtime() = DATA_Time(ch->size());

	//initialize the Mac_header
	bzero(dh, MAC_HDR_LEN);

	dh->dh_fc.fc_protocol_version = MAC_ProtocolVersion;
	dh->dh_fc.fc_type = MAC_Type_Management;
	dh->dh_fc.fc_subtype = MAC_Subtype_BAN;
	dh->dh_fc.fc_to_ds = 0;
	dh->dh_fc.fc_from_ds = 0;
	dh->dh_fc.fc_more_frag = 0;
	dh->dh_fc.fc_retry = 0;
	dh->dh_fc.fc_pwr_mgt = 0;
	dh->dh_fc.fc_more_data = 0;
	dh->dh_fc.fc_wep = 0;
	dh->dh_fc.fc_order = 0;

	STORE4BYTE(&dst, (dh->dh_da));
	STORE4BYTE(&index_, (dh->dh_sa));

	// calculate rts duration field
	dh->dh_duration = DATA_DURATION;

	return p;
	
}
Packet*  MacTdma::generate_FI_packet(){

	slot_tag *fi_local_= this->collected_fi_->slot_describe;
	Packet* p = Packet::alloc();
	struct hdr_cmn* ch = HDR_CMN(p);
	struct hdr_mac_tdma* dh = HDR_MAC_TDMA(p);

	int bit_pos=7, byte_pos=0, fi_size=0;
	int field_length=0,i=0;
	unsigned char buffer=0;
	u_int32_t dst = MAC_BROADCAST;
	unsigned int my_sti = this->global_sti;

	fi_size= (BIT_LENGTH_SLOT_TAG * max_slot_num_ + BIT_LENGTH_STI)/8;
	if(((BIT_LENGTH_SLOT_TAG * max_slot_num_ + BIT_LENGTH_STI) %8) != 0 ){
		fi_size++;
	}
	unsigned char* code = new unsigned char[fi_size];
	for(i=0;i<fi_size;i++){
		code[i]=0;// 将buffer全部清零
	}

	field_length = BIT_LENGTH_STI/8 ;

	if ( BIT_LENGTH_STI%8 != 0 ){
		buffer = (unsigned char)(global_sti>>( 8* field_length ));
		setvalue(buffer, BIT_LENGTH_STI%8, code, byte_pos, bit_pos);
	}

	for(int j = field_length-1 ; j >= 0 ; j-- ){
		buffer = (unsigned char)(global_sti>>(8*j));
		setvalue(buffer, 8, code, byte_pos, bit_pos);
	}


	for(int i=0; i< max_slot_num_; i++){
		buffer = fi_local_[i].busy;
		setvalue(buffer, BIT_LENGTH_BUSY, code, byte_pos, bit_pos);
		//sti
		field_length = BIT_LENGTH_STI/8 ;
		if ( BIT_LENGTH_STI%8 != 0 ){
			buffer= (unsigned char)(fi_local_[i].sti>>( 8* field_length ));
			setvalue(buffer, BIT_LENGTH_STI%8, code, byte_pos, bit_pos);
		}
		for(int j = field_length-1 ; j >= 0 ; j-- ){
			buffer =(unsigned char)(fi_local_[i].sti>>(8*j));
			setvalue(buffer, 8, code, byte_pos, bit_pos);
		}
		//count
		buffer = (unsigned char)fi_local_[i].count_2hop;
		setvalue(buffer, BIT_LENGTH_COUNT, code, byte_pos, bit_pos);

		//PSF
		buffer = fi_local_[i].psf;
		setvalue(buffer, BIT_LENGTH_PSF, code, byte_pos, bit_pos);

		//clear Count_2hop/3hop
		if (fi_local_[i].sti == global_sti) {
			fi_local_[i].count_3hop = 0;
		} else {
			fi_local_[i].c3hop_flag = 0;
			fi_local_[i].count_2hop = 0;
			fi_local_[i].count_3hop = 0;
		}
	}

	p->setdata(fi_size,code);

	ch->uid() = 0;
	ch->ptype() = PT_TDMA;
	ch->size() = fi_size + PHY_TDMA_Overhead();
	ch->iface() = -2;
	ch->error() = 0;
	ch->txtime() = DATA_Time(ch->size());

	//initialize the Mac_header
	bzero(dh, MAC_HDR_LEN);

	dh->dh_fc.fc_protocol_version = MAC_ProtocolVersion;
	dh->dh_fc.fc_type = MAC_Type_Management;
	dh->dh_fc.fc_subtype = MAC_Subtype_Data;
	dh->dh_fc.fc_to_ds = 0;
	dh->dh_fc.fc_from_ds = 0;
	dh->dh_fc.fc_more_frag = 0;
	dh->dh_fc.fc_retry = 0;
	dh->dh_fc.fc_pwr_mgt = 0;
	dh->dh_fc.fc_more_data = 0;
	dh->dh_fc.fc_wep = 0;
	dh->dh_fc.fc_order = 0;

	STORE4BYTE(&dst, (dh->dh_da));
	STORE4BYTE(&index_, (dh->dh_sa));

	// calculate rts duration field
	dh->dh_duration = DATA_DURATION;

	return p;
}
void MacTdma::sendPacket(Packet *&p, int packet_type)
{
	//u_int32_t /*dst, src,*/ size;
	struct hdr_cmn* ch;
	struct hdr_mac_tdma* dh;
	//double stime;

	/* Check if there is any packet buffered. */
	if (!p) {
		printf("<%d>, %f, no FI packet buffered.\n", index_, NOW);
		return;
	}

	/* Perform carrier sence...should not be collision...? */
	if(!is_idle()) {
		//如果在发送的时候看到正在接收那么接收的那个包将不能被正确处理
		if (rx_state_ != MAC_IDLE){
			ch = HDR_CMN(p);
			ch->error() = 1;
			printf("<%d>, %f, New transmitting brings out error happened in receiving...???\n", index_, NOW);
		}
		if (tx_state_ != MAC_IDLE){
			//这里应该不会出现重发的情况，因为发送的顺序将会是FI，完成后安全数据，再完成后才是RTS CTS
			//ch = HDR_CMN(pktRx_);
			//ch->error() = 1;
			printf("<%d>, %f, New transmitting, but last transmit has not finish...???\n", index_, NOW);
		}
	}

	ch = HDR_CMN(p);
	dh = HDR_MAC_TDMA(p);
	dh->send_slot= this->slot_count_;

	/* Turn on the radio and transmit! */
	SET_TX_STATE(MAC_SEND);

	/* Start a timer and update the slot state */
	mhTxPkt_.start(p->copy(), ch->txtime_); //目的是发完控制报文后接着发用户数据。

	downtarget_->recv(p, this);

	switch(packet_type){
		case PACKET_FI:
			slot_state_ = FI;
			break;
		case PACKET_SAFETY:
			slot_state_ = SAFETY;
			break;
		case PACKET_RTS:
			slot_state_ = RTS;
			break;
		case PACKET_CTS:
			slot_state_ = CTS;
			break;
		case PACKET_APP:
			slot_state_ = APP;
			break;
	}

	p = 0;
}

void MacTdma::sendFI()
{
	u_int32_t /*dst, src,*/ size;
	struct hdr_cmn* ch;
	struct hdr_mac_tdma* dh;
	double stime;

	/* Check if there is any packet buffered. */
	if (!pktFI_) {
		printf("<%d>, %f, no FI packet buffered.\n", index_, NOW);
		return;
	}

	/* Perform carrier sence...should not be collision...? */
	if(!is_idle()) {
		//如果在发送的时候看到正在接收那么接收的那个包将不能被正确处理
		if (rx_state_ != MAC_IDLE){
			ch = HDR_CMN(pktRx_);
			ch->error() = 1;
			printf("<%d>, %f, New transmitting brings out error happened in receiving...???\n", index_, NOW);
		}

		if (tx_state_ != MAC_IDLE){
			//这里应该不会出现重发的情况，因为发送的顺序将会是FI，完成后安全数据，再完成后才是RTS CTS
			//ch = HDR_CMN(pktRx_);
			//ch->error() = 1;
			printf("<%d>, %f, New transmitting, but last transmit has not finish...???\n", index_, NOW);
		}

		//here handle the collision problems such as set the back off time
		//return;
	}

	ch = HDR_CMN(pktFI_);
	dh = HDR_MAC_TDMA(pktFI_);

	size = ch->size();
	stime = TX_Time(pktFI_);
	ch->txtime() = stime;
	ch->ptype_ = PT_TDMA;
	dh->send_slot= this->slot_count_;

	/* Turn on the radio and transmit! */
	SET_TX_STATE(MAC_SEND);
	//radioSwitch(ON);

	/* Start a timer that expires when the packet transmission is complete. */
	mhTxPkt_.start(pktFI_->copy(), stime);
	downtarget_->recv(pktFI_, this);

	pktFI_ = 0;
}

/* Actually send the packet from . */
void MacTdma::sendData()
{
	u_int32_t dst, src, size;
	struct hdr_cmn* ch;
	struct hdr_mac_tdma* dh;
	double stime;

	/* Check if there is any packet buffered. */
	if (!pktTx_) {
		printf("<%d>, %f, no packet buffered.\n", index_, NOW);
		return;
	}

	/* Perform carrier sence...should not be collision...? */
	if(!is_idle()) {
		//如果在发送的时候看到正在接收那么接收的那个包将不能被正确处理
		if (rx_state_ != MAC_IDLE){
			ch = HDR_CMN(pktRx_);
			ch->error() = 1;
			printf("<%d>, %f, New transmitting brings out error happened in receiving...???\n", index_, NOW);
		}

		if (tx_state_ != MAC_IDLE){
			//这里应该不会出现重发的情况，因为发送的顺序将会是FI，完成后安全数据，再完成后才是RTS CTS
			//ch = HDR_CMN(pktRx_);
			//ch->error() = 1;
			printf("<%d>, %f, New transmitting, but last transmit has not finish...???\n", index_, NOW);
		}
	}

	ch = HDR_CMN(pktTx_);
	dh = HDR_MAC_TDMA(pktTx_);  

	dst = ETHER_ADDR(dh->dh_da);
	src = ETHER_ADDR(dh->dh_sa);
	size = ch->size();
	stime = TX_Time(pktTx_);
	ch->txtime() = stime;
	ch->ptype_ = PT_TDMA;
	
	/* Turn on the radio and transmit! */
	SET_TX_STATE(MAC_SEND);						     
	//radioSwitch(ON);

	/* Start a timer that expires when the packet transmission is complete. */
	mhTxPkt_.start(pktTx_->copy(), stime);
	downtarget_->recv(pktTx_, this);

	pktTx_ = 0;
}

void MacTdma::sendAll()
{
	u_int32_t /*dst, src,*/ size;
	struct hdr_cmn* ch;
	struct hdr_mac_tdma* dh;
	double stime;

	/* Check if there is any packet buffered. */
	if (!pktFI_) {
		printf("<%d>, %f, no packet buffered.\n", index_, NOW);
		return;
	}

	/* Perform carrier sence...should not be collision...? */
	if(!is_idle()) {
		//如果在发送的时候看到正在接收那么接收的那个包将不能被正确处理
		if (rx_state_ != MAC_IDLE){
			ch = HDR_CMN(pktRx_);
			ch->error() = 1;
			printf("<%d>, %f, New transmitting brings out error happened in receiving...???\n", index_, NOW);
		}

		if (tx_state_ != MAC_IDLE){
			//这里应该不会出现重发的情况，因为发送的顺序将会是FI，完成后安全数据，再完成后才是RTS、CTS
			//ch = HDR_CMN(pktRx_);
			//ch->error() = 1;
			printf("<%d>, %f, New transmitting, but last transmit has not finish...???\n", index_, NOW);
		}

		//here handle the collision problems such as set the back off time
		//return;
	}

	ch = HDR_CMN(pktFI_);
	dh = HDR_MAC_TDMA(pktFI_);

	size = ch->size();
	stime = TX_Time(pktFI_);
	ch->txtime() = stime;
	ch->ptype_ = PT_TDMA;

	/* Turn on the radio and transmit! */
	SET_TX_STATE(MAC_SEND);
	//radioSwitch(ON);

	/* Start a timer that expires when the packet transmission is complete. */
	mhTxPkt_.start(pktFI_->copy(), stime);
	downtarget_->recv(pktFI_, this);

	pktFI_ = 0;
}

// Turn on / off the radio
void MacTdma::radioSwitch(int i) 
{
	radio_active_ = i;
	//EnergyModel *em = netif_->node()->energy_model();
	if (i == ON) {
		//if (em && em->sleep())
		//em->set_node_sleep(0);
		//    printf("<%d>, %f, turn radio ON\n", index_, NOW); 
		Phy *p;
		p = netif_;
		((WirelessPhy *)p)->node_wakeup();
		return;
	}

	if (i == OFF) {
		//if (em && !em->sleep()) {
		//em->set_node_sleep(1);
		//    netif_->node()->set_node_state(INROUTE);
		Phy *p;
		p = netif_;
		((WirelessPhy *)p)->node_sleep();
		//    printf("<%d>, %f, turn radio OFF\n", index_, NOW);
		return;
	}
}

// make the new preamble.
void MacTdma::makePreamble() 
{
	u_int32_t dst;
	struct hdr_mac_tdma* dh;
	
	// If there is a packet buffered, file its destination to preamble.
	if (pktTx_) {
		dh = HDR_MAC_TDMA(pktTx_);  
		dst = ETHER_ADDR(dh->dh_da);
		//printf("<%d>, %f, write %d to slot %d in preamble\n", index_, NOW, dst, slot_num_);
		tdma_preamble_[slot_num_] = dst;
	} else {
		//printf("<%d>, %f, write NO_PKT to slot %d in preamble\n", index_, NOW, slot_num_);
		tdma_preamble_[slot_num_] = NOTHING_TO_SEND;
	}
}

/* Timers' handlers */
/* Slot Timer:
   For the preamble calculation, we should have it:
   occupy one slot time,
   radio turned on for the whole slot.
*/
void MacTdma::slotHandler(Event *e) 
{
	slot_tag *fi_collection = this->collected_fi_->slot_describe;
	send_ban_flag_ = 0;
	// Restart timer for next slot.
	total_slot_count_ = (total_slot_count_+1) % (max_slot_num_ * 10000);//过10000个frame长，totalcount重新开始计算
	slot_count_ = total_slot_count_ %  max_slot_num_;
	mhSlot_.start((Packet *)e, slot_time_);

//TODO 
	/*进行上一个时隙的Fade*/
	this->fade_received_fi_list(1);

	//for those who has listened a whole frame
	slot_state_ = BEGINING;

	if(this->enable == 0){
		double x,y,z;
		((CMUTrace *)this->downtarget_)->getPosition(&x,&y,&z);
		if(z == 0){
			this->enable = 1;
			slot_num_ = (slot_count_+1)% max_slot_num_; //slot_num_初始化为当前的下一个时隙。
		}
	}
	else if(this->enable == 1){
		double x,y,z;
		((CMUTrace *)this->downtarget_)->getPosition(&x,&y,&z);
		if(z > 0 ){
			this->enable = 0;
			//slot_num_ = (slot_count_+1)% max_slot_num_;
		}
	}

	if(this->enable == 0){
		return;
	}


	if (slot_count_ == slot_num_){
		// the first whole slot of a newly initialized node, it begin to listen
		if (node_state_ == NODE_INIT ){
			node_state_ = NODE_LISTEN;

			waiting_frame_count =0;
			request_fail_times = 0;

			return;
		}
		else{
			switch (node_state_) {
			case NODE_LISTEN:
				waiting_frame_count++;

				//根据自己的fi-local，决定自己要申请的slot，修改自己的slot_num_
				this->clear_FI(this->collected_fi_); //初始化
				synthesize_fi_list();
				slot_num_ = determine_BCH(0);
				if(slot_num_ < 0){
					node_state_ = NODE_LISTEN;
					slot_num_ = slot_count_;
					return;
				}
				//如果正好决定的时隙就是本时隙，那么直接发送
				if(slot_num_== slot_count_){
					fi_collection[slot_count_].busy = SLOT_1HOP;
					fi_collection[slot_count_].sti = global_sti;
					fi_collection[slot_count_].count_2hop = 1;
					fi_collection[slot_count_].count_3hop = 1;
					fi_collection[slot_count_].psf = 0;
					pktFI_ = generate_FI_packet(); //必须在BCH状态设置完之后调用。
					//sendFI();
					mhBackoff_.start(0, 1, this->phymib_->SIFSTime);
					node_state_ = NODE_REQUEST;
					return;
				}
				else{//否则等待发送时隙
					node_state_ = NODE_WAIT_REQUEST;
					return;
				}
				break;
			case NODE_WAIT_REQUEST:

				waiting_frame_count++;

				synthesize_fi_list();
				if(fi_collection[slot_count_].sti == global_sti) {
					fi_collection = this->collected_fi_->slot_describe;
					fi_collection[slot_count_].busy = SLOT_1HOP;
					fi_collection[slot_count_].sti = global_sti;
					fi_collection[slot_count_].count_2hop = 1;
					fi_collection[slot_count_].count_3hop = 1;
					fi_collection[slot_count_].psf = 0;
					pktFI_ = generate_FI_packet(); //必须在BCH状态设置完之后调用。
					//sendFI();
					mhBackoff_.start(0, 1, this->phymib_->SIFSTime);
					node_state_ = NODE_REQUEST;
					return;
				} else {
					slot_num_ = determine_BCH(0);
					if(slot_num_ < 0){
						node_state_ = NODE_LISTEN;
						slot_num_ = slot_count_;
						return;
					}
					//一般不会发生，因为上面的判定条件注定本时隙不是free的不可能被选择出来。
					if(slot_num_== slot_count_){
						fi_collection[slot_count_].busy = SLOT_1HOP;
						fi_collection[slot_count_].sti = global_sti;
						fi_collection[slot_count_].count_2hop = 1;
						fi_collection[slot_count_].count_3hop = 1;
						fi_collection[slot_count_].psf = 0;
						pktFI_ = generate_FI_packet(); //必须在BCH状态设置完之后调用。
						//sendFI();
						mhBackoff_.start(0, 1, this->phymib_->SIFSTime);
						node_state_ = NODE_REQUEST;
						return;
					}
					else{//否则等待发送时隙
						node_state_ = NODE_WAIT_REQUEST;
						return;
					}
				}
				break;
			case NODE_REQUEST:// or node_state_ = NODE_WORK;;

				synthesize_fi_list();
				if(fi_collection[slot_count_].sti == global_sti) {
					waiting_frame_count++;
					node_state_ = NODE_WORK_FI;
					pktFI_ = generate_FI_packet(); 
					//sendFI();
					mhBackoff_.start(0, 1, this->phymib_->SIFSTime);
					int offset = strlen(((CMUTrace *)this->downtarget_)->pt_->buffer());
					if(offset!=0){
						//((CMUTrace *)this->downtarget_)->pt_->dump();
						offset=0;
					}
					sprintf(((CMUTrace *)this->downtarget_)->pt_->buffer() + offset,
							"m %.9f t[%d] _%d_ SOR %d %d",
							NOW, slot_num_, global_sti, waiting_frame_count ,request_fail_times );
					((CMUTrace *)this->downtarget_)->pt_->dump();
					//printf(" %.9f <%d>, get BCH(%d) after %d frames and %d request failures! \n", NOW, sti, slot_num_ ,waiting_frame_count ,request_fail_times );
				} else {
					slot_num_ = determine_BCH(0);
					if(slot_num_ < 0){
						node_state_ = NODE_LISTEN;
						slot_num_ = slot_count_;
						return;
					} else {
						node_state_ = NODE_WAIT_REQUEST;
						return;
					}
				}
				break;
			case NODE_WORK_FI:
				synthesize_fi_list();
				if(fi_collection[slot_count_].sti == global_sti) //BCH可用
				{
					if (adjust_is_needed(slot_num_)) {
						node_state_ = NODE_WORK_ADJ;
						slot_adj_candidate_ = determine_BCH(1);
						fi_collection[slot_adj_candidate_].busy = SLOT_1HOP;
						fi_collection[slot_adj_candidate_].sti = global_sti;
						fi_collection[slot_adj_candidate_].count_2hop = 1;
						fi_collection[slot_adj_candidate_].count_3hop = 1;
						fi_collection[slot_adj_candidate_].psf = 0;
					}
					pktFI_ = generate_FI_packet(); 
					//sendFI();
					mhBackoff_.start(0, 1, this->phymib_->SIFSTime);
				}
				break;	
			case NODE_WORK_ADJ:
				synthesize_fi_list();
				if(fi_collection[slot_adj_candidate_].sti == global_sti) {//BCH依然可用
					node_state_ = NODE_WORK_FI;
					slot_num_ = slot_adj_candidate_;
					pktFI_ = generate_FI_packet(); 
					pktBAN_ = generate_BAN_packet();
					//send FI then BAN;
					send_ban_flag_ = 1;// will be cleared in backoffHandler.
					mhBackoff_.start(0, 1, this->phymib_->SIFSTime);
					
				} else { //BCH已经不可用
					if(fi_collection[slot_adj_candidate_].sti == global_sti) { //ADJ时隙可用
						node_state_ = NODE_WORK_FI;
						slot_num_ = slot_adj_candidate_;
					} else { //ADJ时隙不可用
						slot_num_ = determine_BCH(0);
						if(slot_num_ < 0){
							node_state_ = NODE_LISTEN;
							slot_num_ = slot_count_;
							return;
						} else {
							node_state_ = NODE_WAIT_REQUEST;
							return;
						}
					}
				}
				break;
			}
		}

	}

	return;
}

/*
void MacTdma::set_cetain_slot_tag(int index, unsigned char busy,unsigned long long sti, unsigned char psf, unsigned char ptp) {
	assert(index >= 0);
	for(int i=0; i< max_slot_num_; i++){
		fi_list_[i][index].busy = busy;
		fi_list_[i][index].sti = sti;
		fi_list_[i][index].psf = psf;
		fi_list_[i][index].ptp = ptp;
	}
}*/

void MacTdma::recvHandler(Event *e) 
{
	u_int32_t dst, src; 
	//int size;
	struct hdr_cmn *ch = HDR_CMN(pktRx_);
	struct hdr_mac_tdma *dh = HDR_MAC_TDMA(pktRx_);

	/* Check if any collision happened while receiving. */
	if (rx_state_ == MAC_COLL){
		//ch->error() = 1;
		discard(pktRx_, DROP_MAC_COLLISION);
		SET_RX_STATE(MAC_IDLE);
		return;

	}
	else if(rx_state_ == MAC_BUSY){
		//ch->error() = 1;
		discard(pktRx_, DROP_MAC_BUSY);
		SET_RX_STATE(MAC_IDLE);
		return;
	}
	else{

		SET_RX_STATE(MAC_IDLE);
		/*
		 * Check to see if this packet was received with enough
		 * bit errors that the current level of FEC still could not
		 * fix all of the problems - ie; after FEC, the checksum still
		 * failed.
		 */
		if( ch->error() ) {
			Packet::free(pktRx_);
			return;
		}

		/* check if this packet was unicast and not intended for me, drop it.*/
		dst = ETHER_ADDR(dh->dh_da);
		src = ETHER_ADDR(dh->dh_sa);
		//size = ch->size();

		//printf("<%d>, %f, recv a packet [from %d to %d], size = %d\n", index_, NOW, src, dst, size);

		// Turn the radio off after receiving the whole packet
		//radioSwitch(OFF);

		/* Ordinary operations on the incoming packet */
		// Not a pcket destinated to me.
		if ((dst != MAC_BROADCAST) && (dst != (u_int32_t)index_)) {
			drop(pktRx_);
			return;
		}

		/* Now forward packet upwards. */
		recvPacket(pktRx_);
	}
}

void MacTdma::sendHandler(Event *e) 
{

	double remain_time;
	struct hdr_cmn* ch;

	/* Once transmission is complete, drop the packet. p is just for schedule a event. */
	SET_TX_STATE(MAC_IDLE);
	Packet::free((Packet *)e);
	// Turn off the radio after sending the whole packet
	// radioSwitch(OFF);

	/* unlock IFQ. */
	if(callback_) {
		Handler *h = callback_;
		callback_ = 0;
		h->handle((Event*) 0);
	} 

	switch (this->node_state_){
			case NODE_LISTEN:
				printf("NODE_LISTEN should not have sent a packet!\n");
				break;
			case NODE_WAIT_REQUEST:
				printf("NODE_WAIT_REQUEST should not have sent a packet!\n");
				break;
			case NODE_INIT:
				printf("NODE_INIT should not have sent a REQ packet!\n");
				break;
			case NODE_REQUEST:
				//do nothing!
				break;
			case NODE_WORK_FI:
			case NODE_WORK_ADJ:		
				if(this->slot_state_ == BEGINING){
					printf("TYPE_FI slot is BEGINING, there should be no packet sent! \n");
					break;
				}
				else if(this->slot_state_ == FI){
					if(!safety_packet_queue_->Isempty()){
						remain_time = get_Remain_slottime();
						ch = HDR_CMN(safety_packet_queue_->QueueHead());
						if(remain_time > (ch->txtime_ + this->phymib_->SIFSTime)){
							mhBackoff_.start(0, 1, this->phymib_->SIFSTime);
						}
						else{
							this->slot_state_ = SAFETY;
						}
					}
					else{
						this->slot_state_ = SAFETY;
					}
				}
				else{
					//do nothing
					//节点发送安全信息，那么本时隙的发送任务完成了。
				}
				break;
		}
}


int MacTdma::slot_available(int slot_num){
	slot_tag *fi_found;
	fi_found = this->collected_fi_->slot_describe;

	if (fi_found[slot_num].sti == global_sti)
		return 1;
	else
		return 0;
}

//初始化一个fi记录
void MacTdma::clear_FI(Frame_info *fi){
	//fi->frame_len;
	//fi->index;
	//fi->sti;
	fi->valid_time = 0;
	fi->remain_time = 0;
	fi->recv_slot = -1;
	if(fi->slot_describe != NULL){
		delete[] fi->slot_describe;
	}
	fi->slot_describe = new slot_tag[frame_len_];
}

void
MacTdma::backoffHandler(Event *e)
{
	Frame_info *current, *best;
	//slot_tag* fi_decision = decision_fi_->slot_describe;
	current = this->received_fi_list_;
	//int remain_slot;
	double remain_time;
	//int n;
	//int selected_slot;
	struct hdr_cmn* ch;
	Packet* p;
	//int slot_num;

	best = NULL;

	//if(this->is_idle()){
		switch (this->node_state_){
			case NODE_REQUEST:
				if(this->slot_state_ == BEGINING){
					int offset = strlen(((CMUTrace *)this->downtarget_)->pt_->buffer());
					if(offset != 0){
						//((CMUTrace *)this->downtarget_)->pt_->dump();
						offset = 0;
					}
					sprintf(((CMUTrace *)this->downtarget_)->pt_->buffer() + offset,
								"m %.9f t[%d] _%d_ REQ %d %d",
								NOW, slot_num_, global_sti, waiting_frame_count ,request_fail_times );
					((CMUTrace *)this->downtarget_)->pt_->dump();

					/*if(this->sti == 8 ){
						double nowtime = 0;
						nowtime = NOW;
						printf("here");
					}*/

					this->sendPacket(this->pktFI_,PACKET_FI);
				}
				else{
					printf("NODE_REQUEST slot should only send FI packet!\n");
				}
				break;

			case NODE_WORK_FI:
				if(this->slot_state_ == BEGINING){
					this->sendPacket(this->pktFI_,PACKET_FI);
				}
				else if(this->slot_state_ == FI){
					remain_time = get_Remain_slottime();
					p = safety_packet_queue_->QueueHead();
					ch = HDR_CMN(p);
					if(remain_time > ch->txtime_ ){
						p = safety_packet_queue_->Dequeue();
						//this->sendPacket(p,PACKET_FI);
						this->sendPacket(p,PACKET_SAFETY);
						/*printf("Node<%d>: Receive %d packets from up layer, send %d packets out! Receive %d packets from other node!\n"
									,this->sti
									,packet_sended
									,packet_sended-safety_packet_queue_->Size()
									,packet_received);*/
					}
					else{
						this->slot_state_ = SAFETY;
					}
				}
				else{
					printf("NODE_REQUEST slot should only send FI and SAFTY packet!\n");
				}
				break;
			case NODE_WORK_ADJ:
				if(this->slot_state_ == BEGINING){
					if (send_ban_flag_) {
						send_ban_flag_ = 0;
						this->sendPacket(this->pktFI_,BEGINING);
						this->sendPacket(this->pktBAN_,PACKET_FI);
					} else
						this->sendPacket(this->pktFI_,PACKET_FI);
				}
				else if(this->slot_state_ == FI){
					remain_time = get_Remain_slottime();
					p = safety_packet_queue_->QueueHead();
					ch = HDR_CMN(p);
					if(remain_time > ch->txtime_ ){
						p = safety_packet_queue_->Dequeue();
						//this->sendPacket(p,PACKET_FI);
						this->sendPacket(p,PACKET_SAFETY);
						/*printf("Node<%d>: Receive %d packets from up layer, send %d packets out! Receive %d packets from other node!\n"
									,this->sti
									,packet_sended
									,packet_sended-safety_packet_queue_->Size()
									,packet_received);*/
					}
					else{
						this->slot_state_ = SAFETY;
					}
				}
				else{
					printf("NODE_REQUEST slot should only send FI and SAFTY packet!\n");
				}
				break;

			case NODE_LISTEN:
				printf("NODE_LISTEN should not have sent a packet!\n");
				break;
			case NODE_WAIT_REQUEST:
				printf("NODE_WAIT_REQUEST should not have sent a packet!\n");
				break;
			case NODE_INIT:
				printf("NODE_INIT should not have sent a REQ packet!\n");
				break;
		}
	//}
	//else{
		//mhBackoff_.start(1, 1, 0);
	//}
	return;
}

int MacTdma::slot_lifetime_frame_ = 0;
int MacTdma::c3hop_threshold_s1_ = 0;
int MacTdma::c3hop_threshold_s2_ = 0;

double MacTdma::slot_time_ =0;
double MacTdma::start_time_ = 0;
int MacTdma::active_node_ = 0;
int MacTdma::max_slot_num_ = 0;
int *MacTdma::tdma_schedule_ = NULL;
int *MacTdma::tdma_preamble_ = NULL;

int MacTdma::tdma_ps_ = 0;
int MacTdma::tdma_pr_ = 0;

int MacTdma::frame_len_ = 0;
//int MacTdma::collision_count_;

