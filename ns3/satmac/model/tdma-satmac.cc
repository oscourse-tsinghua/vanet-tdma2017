/* -*- Mode:C++; c-file-style:"gnu"; indent-tabs-mode:nil; -*- */

#include "ns3/assert.h"
#include "ns3/enum.h"
#include "ns3/log.h"
#include "ns3/simulator.h"
#include "tdma-satmac.h"
#include "tdma-mac.h"
#include "tdma-mac-low.h"
#include "satmac-packet.h"
#include "ns3/abort.h"
#include "ns3/integer.h"
#include <map>
#include <iostream>
#include <string>
#include <fstream>

NS_LOG_COMPONENT_DEFINE ("TdmaSatmac");

#define MY_DEBUG(x) \
  NS_LOG_DEBUG (Simulator::Now () << " " << this << " " << x)

namespace ns3 {
NS_OBJECT_ENSURE_REGISTERED (TdmaSatmac);

Time
TdmaSatmac::GetDefaultSlotTime (void)
{
  return MicroSeconds (1000);
}

Time
TdmaSatmac::GetDefaultGuardTime (void)
{
  return MicroSeconds (50);
}

DataRate
TdmaSatmac::GetDefaultDataRate (void)
{
  NS_LOG_DEBUG ("Setting default");
  return DataRate ("12000000b/s");
}

int TdmaSatmac::GetDefaultFrameLen(void) 
{
  return 64;
}

int TdmaSatmac::GetDefaultSlotLife(void) 
{
  return 3;
}

int TdmaSatmac::GetDefaultC3HThreshold(void) 
{
  return 2;
}
int TdmaSatmac::GetDefaultAdjThreshold(void) 
{
  return 5;
}
int TdmaSatmac::GetDefaultRandomBchIfSingle(void) 
{
  return 1;
}
int TdmaSatmac::GetDefaultAdjEnable(void) 
{
  return 1;
}
int TdmaSatmac::GetDefaultAdjFrameEnable(void) 
{
  return 1;
}

int TdmaSatmac::GetDefaultAdjFrameLowerBound(void)
{
  return 32;
}

int TdmaSatmac::GetDefaultAdjFrameUpperBound(void) 
{
  return 128;
}

int TdmaSatmac::GetDefaultSlotMemory(void) 
{
  return 1;
}


/*************************************************************
 * Tdma Controller Class Functions
 ************************************************************/
TypeId
TdmaSatmac::GetTypeId (void)
{
  static TypeId tid = TypeId ("ns3:TdmaSatmac")
    .SetParent<TdmaMac> ()
    .AddConstructor<TdmaSatmac> ()
    .AddAttribute ("DataRate",
                   "The default data rate for point to point links",
                   DataRateValue (GetDefaultDataRate ()),
                   MakeDataRateAccessor (&TdmaSatmac::SetDataRate,
                                         &TdmaSatmac::GetDataRate),
                   MakeDataRateChecker ())
    .AddAttribute ("SlotTime", "The duration of a Slot in microseconds.",
                   TimeValue (GetDefaultSlotTime ()),
                   MakeTimeAccessor (&TdmaSatmac::SetSlotTime,
                                     &TdmaSatmac::GetSlotTime),
                   MakeTimeChecker ())
    .AddAttribute ("GuardTime", "GuardTime between TDMA slots in microseconds.",
                   TimeValue (GetDefaultGuardTime ()),
                   MakeTimeAccessor (&TdmaSatmac::SetGuardTime,
                                     &TdmaSatmac::GetGuardTime),
                   MakeTimeChecker ())
    .AddAttribute ("InterFrameTime", "The wait time between consecutive tdma frames.",
                   TimeValue (MicroSeconds (0)),
                   MakeTimeAccessor (&TdmaSatmac::SetInterFrameTimeInterval,
                                     &TdmaSatmac::GetInterFrameTimeInterval),
                   MakeTimeChecker ())

	  .AddAttribute ("STI", "",
					 IntegerValue (-1),
					 MakeIntegerAccessor (&TdmaSatmac::SetGlobalSti,
									   &TdmaSatmac::GetGlobalSti),
					 MakeIntegerChecker<int> (0,9999))
	  .AddAttribute ("FrameLen", "",
					 IntegerValue (GetDefaultFrameLen()),
					 MakeIntegerAccessor (&TdmaSatmac::SetFrameLen,
									   &TdmaSatmac::GetFrameLen),
					 MakeIntegerChecker<int> (1,129))
	  .AddAttribute ("SlotLife", "",
					 IntegerValue (GetDefaultSlotLife()),
					 MakeIntegerAccessor (&TdmaSatmac::SetSlotLife,
									   &TdmaSatmac::GetSlotLife),
					 MakeIntegerChecker<int> (0,20))
	  .AddAttribute ("C3HThreshold", "",
					 IntegerValue (GetDefaultC3HThreshold()),
					 MakeIntegerAccessor (&TdmaSatmac::SetC3HThreshold,
									   &TdmaSatmac::GetC3HThreshold),
					 MakeIntegerChecker<int> (0,10))
	  .AddAttribute ("AdjThreshold", "",
					 IntegerValue (GetDefaultAdjThreshold()),
					 MakeIntegerAccessor (&TdmaSatmac::SetAdjThreshold,
									   &TdmaSatmac::GetAdjThreshold),
					 MakeIntegerChecker<int> (0,50))
	  .AddAttribute ("RandomBchIfSingle", "",
					 IntegerValue (GetDefaultRandomBchIfSingle()),
					 MakeIntegerAccessor (&TdmaSatmac::SetRandomBchIfSingle,
									   &TdmaSatmac::GetRandomBchIfSingle),
					 MakeIntegerChecker<int> (0,1))
	  .AddAttribute ("AdjEnable", "",
					 IntegerValue (GetDefaultAdjEnable()),
					 MakeIntegerAccessor (&TdmaSatmac::SetAdjEnable,
									   &TdmaSatmac::GetAdjEnable),
					 MakeIntegerChecker<int> (0,1))
	  .AddAttribute ("AdjFrameEnable", "",
					 IntegerValue (GetDefaultAdjFrameEnable()),
					 MakeIntegerAccessor (&TdmaSatmac::SetAdjFrameEnable,
									   &TdmaSatmac::GetAdjFrameEnable),
					 MakeIntegerChecker<int> (0,1))
	  .AddAttribute ("AdjFrameLowerBound", "",
					 IntegerValue (GetDefaultAdjFrameLowerBound()),
					 MakeIntegerAccessor (&TdmaSatmac::SetAdjFrameLowerBound,
									   &TdmaSatmac::GetAdjFrameLowerBound),
					 MakeIntegerChecker<int> (1,129))
	  .AddAttribute ("AdjFrameUpperBound", "",
					 IntegerValue (GetDefaultAdjFrameUpperBound()),
					 MakeIntegerAccessor (&TdmaSatmac::SetAdjFrameUpperBound,
									   &TdmaSatmac::GetAdjFrameUpperBound),
					 MakeIntegerChecker<int> (1,129))
	  .AddAttribute ("SlotMemory", "",
					 IntegerValue (GetDefaultSlotMemory()),
					 MakeIntegerAccessor (&TdmaSatmac::SetSlotMemory,
									   &TdmaSatmac::GetSlotMemory),
					 MakeIntegerChecker<int> (0,1))
  ;
  return tid;
}

TdmaSatmac::TdmaSatmac ()
{
  global_sti = 599;
  NS_LOG_FUNCTION (this);
  m_traceOutFile = "lpf-output.txt";
  m_wifimaclow_flag = 0;
  m_low = CreateObject<TdmaMacLow> ();
  m_queue = CreateObject<TdmaMacQueue> ();
  m_queue->SetTdmaMacTxDropCallback (MakeCallback (&TdmaSatmac::NotifyTxDrop, this));
  m_uniformRandomVariable = CreateObject<UniformRandomVariable> ();
  m_transmissionListener = new TransmissionListenerUseless ();

  m_queue->SetMacPtr (this);
  m_low->SetRxCallback (MakeCallback (&TdmaSatmac::Receive, this));
  TdmaMac::DoInitialize ();
}

TdmaSatmac::~TdmaSatmac ()
{
  m_channel = 0;
  m_bps = 0;
}

void
TdmaSatmac::Start (void)
{
  NS_LOG_FUNCTION (this);
  total_slot_count_ = 0;
  slot_count_ = 0;
  slot_num_ = (slot_count_+1)% m_frame_len; //slot_num_初始化为当前的下一个时隙。

  global_psf = 0;
  collected_fi_ = new Frame_info(512);
  collected_fi_->sti = this->global_sti;
  received_fi_list_= NULL;

  node_state_ = NODE_INIT;
  slot_state_ = BEGINING;
  collision_count_ = 0;
  localmerge_collision_count_ = 0;
  request_fail_times = 0;
  waiting_frame_count = 0;
  frame_count_ = 0;
  this->enable=0;
  this->packet_sended = 0;
  this->packet_received =0;

//  std::cout<<"Start time:" << Simulator::Now().GetMicroSeconds() << "ID: " << this->GetGlobalSti() << std::endl;
//NanoSeconds
  Simulator::Schedule (NanoSeconds (50),&TdmaSatmac::slotHandler, this);
}

void
TdmaSatmac::Initialize ()
{
  NS_LOG_FUNCTION_NOARGS ();
  Start();
}

void
TdmaSatmac::DoDispose (void)
{
  m_low->Dispose ();
  m_low = 0;
  m_device = 0;
  m_queue = 0;
  TdmaMac::DoDispose ();
}

void
TdmaSatmac::NotifyTx (Ptr<const Packet> packet)
{
  m_macTxTrace (packet);
}

void
TdmaSatmac::NotifyTxDrop (Ptr<const Packet> packet)
{
  m_macTxDropTrace (packet);
}

void
TdmaSatmac::NotifyRx (Ptr<const Packet> packet)
{
  m_macRxTrace (packet);
}

void
TdmaSatmac::NotifyPromiscRx (Ptr<const Packet> packet)
{
  m_macPromiscRxTrace (packet);
}

void
TdmaSatmac::NotifyRxDrop (Ptr<const Packet> packet)
{
  m_macRxDropTrace (packet);
}

void
TdmaSatmac::SetDevice (Ptr<TdmaNetDevice> device)
{
  m_device = device;
  m_low->SetDevice (m_device);
}

Ptr<TdmaNetDevice>
TdmaSatmac::GetDevice (void) const
{
  return m_device;
}

Ptr<TdmaMacLow>
TdmaSatmac::GetTdmaMacLow (void) const
{
  return m_low;
}

void
TdmaSatmac::SetForwardUpCallback (Callback<void, Ptr<Packet>, const WifiMacHeader*> upCallback)
{
  NS_LOG_FUNCTION (this);
  m_upCallback = upCallback;
}

void
TdmaSatmac::SetLinkUpCallback (Callback<void> linkUp)
{
  linkUp ();
}
void
TdmaSatmac::SetLinkDownCallback (Callback<void> linkDown)
{
}
void
TdmaSatmac::SetTxQueueStartCallback (Callback<bool,uint32_t> queueStart)
{
  NS_LOG_FUNCTION (this);
  m_queueStart = queueStart;
}

void
TdmaSatmac::SetTxQueueStopCallback (Callback<bool,uint32_t> queueStop)
{
  NS_LOG_FUNCTION (this);
  m_queueStop = queueStop;
}

uint32_t
TdmaSatmac::GetQueueState (uint32_t index)
{
  if (m_queue->GetMaxSize () == m_queue->GetSize ())
    {
      return 0;
    }
  else
    {
      return 1;
    }
}

uint32_t
TdmaSatmac::GetNQueues (void)
{
  //TDMA currently has only one queue
  return 1;
}


void
TdmaSatmac::SetMaxQueueSize (uint32_t size)
{
  NS_LOG_FUNCTION (this << size);
  m_queue->SetMaxSize (size);
}
void
TdmaSatmac::SetMaxQueueDelay (Time delay)
{
  NS_LOG_FUNCTION (this << delay);
  m_queue->SetMaxDelay (delay);
}


Mac48Address
TdmaSatmac::GetAddress (void) const
{
  if (!m_wifimaclow_flag)
    return m_low->GetAddress ();
  else
	return m_wifimaclow->GetAddress();
}
Ssid
TdmaSatmac::GetSsid (void) const
{
  return m_ssid;
}
void
TdmaSatmac::SetAddress (Mac48Address address)
{
  NS_LOG_FUNCTION (address);
  m_low->SetAddress (address);
  m_low->SetBssid (address);
}
void
TdmaSatmac::SetSsid (Ssid ssid)
{
  NS_LOG_FUNCTION (ssid);
  m_ssid = ssid;
}
Mac48Address
TdmaSatmac::GetBssid (void) const
{
  return m_low->GetBssid ();
}

void
TdmaSatmac::Queue (Ptr<const Packet> packet, const WifiMacHeader &hdr)
{
  NS_LOG_FUNCTION (this << packet << &hdr);
  if (!m_queue->Enqueue (packet, hdr))
    {
      NotifyTxDrop (packet);
    }

#ifdef PRINT_SLOT_STATUS
  printf("I'm node %d, in slot %d, I Queue a data packet\n", global_sti, slot_count_);
#endif
  //Cannot request for channel access in tdma. Tdma schedules every node in round robin manner
  //RequestForChannelAccess();
}

void
TdmaSatmac::SetSlotTime (Time slotTime)
{
  NS_LOG_FUNCTION (this << slotTime);
  m_slotTime = slotTime.GetMicroSeconds ();
}

Time
TdmaSatmac::GetSlotTime (void) const
{
  return MicroSeconds (m_slotTime);
}

void
TdmaSatmac::SetDataRate (DataRate bps)
{
  NS_LOG_FUNCTION (this << bps);
  m_bps = bps;
}

DataRate
TdmaSatmac::GetDataRate (void) const
{
  return m_bps;
}

void
TdmaSatmac::SetChannel (Ptr<SimpleWirelessChannel> c)
{
  if (c != 0)
	{
	  m_channel = c;
	  m_low->SetChannel (m_channel);
	}
}


Ptr<SimpleWirelessChannel>
TdmaSatmac::GetChannel (void) const
{
  NS_LOG_FUNCTION (this);
  return m_channel;
}

void
TdmaSatmac::SetGuardTime (Time guardTime)
{
  NS_LOG_FUNCTION (this << guardTime);
  //guardTime is based on the SimpleWirelessChannel's max range
  if (m_channel != 0)
    {
      m_guardTime = Seconds (m_channel->GetMaxRange () / 300000000.0).GetMicroSeconds ();
    }
  else
    {
      m_guardTime = guardTime.GetMicroSeconds ();
    }
}

Time
TdmaSatmac::GetGuardTime (void) const
{
  return MicroSeconds (m_guardTime);
}

void
TdmaSatmac::SetInterFrameTimeInterval (Time interFrameTime)
{
  NS_LOG_FUNCTION (interFrameTime);
  m_tdmaInterFrameTime = interFrameTime.GetMicroSeconds ();
}

Time
TdmaSatmac::GetInterFrameTimeInterval (void) const
{
  return MicroSeconds (m_tdmaInterFrameTime);
}

void TdmaSatmac::SetGlobalSti(int sti)
{
  global_sti = sti;
}
int TdmaSatmac::GetGlobalSti(void) const
{
  return global_sti;
}

void TdmaSatmac::SetFrameLen(int framelen)
{
  m_frame_len = framelen;
}
int TdmaSatmac::GetFrameLen(void) const
{
  return m_frame_len;
}

void TdmaSatmac::SetSlotLife(int slotlife_perframe)
{
  slot_lifetime_frame_ = slotlife_perframe;
}

int TdmaSatmac::GetSlotLife(void) const
{
  return slot_lifetime_frame_;
}

void TdmaSatmac::SetC3HThreshold(int c3h_threshold)
{
  c3hop_threshold_ = c3h_threshold;
}

int TdmaSatmac::GetC3HThreshold(void) const
{
  return c3hop_threshold_;
}

void TdmaSatmac::SetAdjThreshold(int adj_threshold)
{
  adj_free_threshold_ = adj_threshold;
}

int TdmaSatmac::GetAdjThreshold(void) const
{
  return adj_free_threshold_;
}

void TdmaSatmac::SetRandomBchIfSingle(int flag)
{
  random_bch_if_single_switch_ = flag;
}

int TdmaSatmac::GetRandomBchIfSingle(void) const
{
  return random_bch_if_single_switch_;
}

void TdmaSatmac::SetAdjEnable(int flag)
{
  adj_ena_ = flag;
}

int TdmaSatmac::GetAdjEnable(void) const
{
  return adj_ena_;
}

void TdmaSatmac::SetAdjFrameEnable(int flag)
{
  adj_frame_ena_ = flag;
}

int TdmaSatmac::GetAdjFrameEnable(void) const
{
  return adj_frame_ena_;
}

void TdmaSatmac::SetAdjFrameLowerBound(int lowerbound)
{
  adj_frame_lower_bound_ = lowerbound;
}

int TdmaSatmac::GetAdjFrameLowerBound(void) const
{
  return adj_frame_lower_bound_;
}

void TdmaSatmac::SetAdjFrameUpperBound(int upperbound)
{
  adj_frame_upper_bound_ = upperbound;
}

int TdmaSatmac::GetAdjFrameUpperBound(void) const
{
  return adj_frame_upper_bound_;
}

void TdmaSatmac::SetSlotMemory(int flag)
{
  slot_memory_ = flag;
}

int TdmaSatmac::GetSlotMemory(void) const
{
  return slot_memory_;
}

void TransmissionListenerUseless::EndTxNoAck()
{
	  txok = true;
}

void
TdmaSatmac::Enqueue (Ptr<const Packet> packet, Mac48Address to, Mac48Address from)
{
  NS_LOG_FUNCTION (this << packet << to << from);
  WifiMacHeader hdr;
  hdr.SetType (WIFI_MAC_DATA);
  hdr.SetAddr1 (to);
  hdr.SetAddr2 (GetAddress ());
  hdr.SetAddr3 (from);
  hdr.SetDsFrom ();
  hdr.SetDsNotTo ();
  Queue (packet, hdr);
}
void
TdmaSatmac::Enqueue (Ptr<const Packet> packet, Mac48Address to)
{
  NS_LOG_FUNCTION (this << packet << to);
  WifiMacHeader hdr;
  hdr.SetType (WIFI_MAC_DATA);
  hdr.SetAddr1 (to);
  hdr.SetAddr2 (GetAddress ());
  hdr.SetAddr3 (m_low->GetAddress ());
  hdr.SetDsFrom ();
  hdr.SetDsNotTo ();
  Queue (packet, hdr);
  NS_LOG_FUNCTION (this << packet << to);
}

void TdmaSatmac::Enqueue (Ptr<const Packet> packet, WifiMacHeader hdr)
{
	Queue (packet, hdr);
}

bool
TdmaSatmac::SupportsSendFrom (void) const
{
  return true;
}

void
TdmaSatmac::TxOk (const WifiMacHeader &hdr)
{
}
void
TdmaSatmac::TxFailed (const WifiMacHeader &hdr)
{
}

void
TdmaSatmac::TxQueueStart (uint32_t index)
{
  NS_ASSERT (index < GetNQueues ());
  m_queueStart (index);
}
void
TdmaSatmac::TxQueueStop (uint32_t index)
{
  NS_ASSERT (index < GetNQueues ());
  m_queueStop (index);
}

void TdmaSatmac::show_slot_occupation() {
	int i,free_count = 0;
	std::map<unsigned int,int> omap;
	slot_tag *fi_local_= this->collected_fi_->slot_describe;
	for(i=0 ; i < m_frame_len; i++){
		if(fi_local_[i].busy== SLOT_FREE)
			free_count++;
		else {
			if (omap[fi_local_[i].sti])
				NS_LOG_DEBUG("Node " << fi_local_[i].sti <<" has occupied more than one slot!");
			else
				omap[fi_local_[i].sti] = 1;
		}
	}
	NS_LOG_DEBUG("FREE SLOT: " << free_count);
}

void TdmaSatmac::clear_others_slot_status() {
	slot_tag *fi_local = this->collected_fi_->slot_describe;
	int count;
	for (count=0; count < m_frame_len; count++){
		if (fi_local[count].sti != global_sti) {
			fi_local[count].busy = SLOT_FREE;
			fi_local[count].sti = 0;
			fi_local[count].count_2hop = 0;
			fi_local[count].count_3hop = 0;
			fi_local[count].psf = 0;
			fi_local[count].locker = 0;
		}
	}
}

//初始化一个fi记录
void TdmaSatmac::clear_FI(Frame_info *fi){
	//fi->frame_len;
	//fi->index;
	//fi->sti;
	fi->valid_time = 0;
	fi->remain_time = 0;
	fi->recv_slot = -1;
	if(fi->slot_describe != NULL){
		delete[] fi->slot_describe;
	}
	fi->slot_describe = new slot_tag[512];
}

/*
 * allocate a new fi and add insert in the head of received_fi_list;
 */
Frame_info * TdmaSatmac::get_new_FI(int slot_count){
	Frame_info *newFI= new Frame_info(slot_count);
//	newFI->next_fi = this->received_fi_list_;
	Frame_info *tmp;

	if (received_fi_list_ == NULL)
		received_fi_list_ = newFI;
	else {
		for (tmp = received_fi_list_; tmp->next_fi != NULL; tmp = tmp->next_fi) {}
		tmp->next_fi = newFI;
	}
	newFI->next_fi = NULL;

	return newFI;
}

void TdmaSatmac::print_slot_status(void) {
	slot_tag *fi_local = this->collected_fi_->slot_describe;
	int i, count;
	int free_count_ths = 0, free_count_ehs = 0;
	for(i=0 ; i < m_frame_len; i++){
		if (fi_local[i].busy== SLOT_FREE)
			free_count_ths++;
		if(fi_local[i].busy== SLOT_FREE && fi_local[i].count_3hop == 0)
			free_count_ehs++;
	}
	NS_LOG_DEBUG("I'm node "<<global_sti<<" in slot " <<slot_count_<<" FreeThs: "<<free_count_ths<<", Ehs "
			<<free_count_ehs<<" total "<< m_frame_len<<" status: ");
	for (count=0; count < m_frame_len; count++){
		NS_LOG_DEBUG("|| "<< fi_local[count].sti<<" ");
		switch (fi_local[count].busy) {
		case SLOT_FREE:
			NS_LOG_DEBUG("(0,0) ");
			break;
		case SLOT_1HOP:
			NS_LOG_DEBUG("(1,0) ");
			break;
		case SLOT_2HOP:
			NS_LOG_DEBUG("(0,1) ");
			break;
		case SLOT_COLLISION:
			NS_LOG_DEBUG("(1,1) ");
			break;
		}

		NS_LOG_DEBUG("c:"<< fi_local[count].count_2hop<<"/"<<fi_local[count].count_3hop<<" ");
	}
	NS_LOG_DEBUG("");
}

bool TdmaSatmac::isNewNeighbor(int sid) {
	slot_tag *fi_local = this->collected_fi_->slot_describe;
	int count;
	for (count=0; count < m_frame_len; count++){
		if (fi_local[count].sti == sid)
			return false;
	}
	return true;
}

/* This function is used to pick up a random slot of from those which is free. */
int TdmaSatmac::determine_BCH(bool strict){
	int i=0,chosen_slot=0;
//	int loc;
	slot_tag *fi_local_= this->collected_fi_->slot_describe;
//	int s1c[256];
	int s2c[256];
	int s0c[256];
	int s0_1c[128];
//	int s2_1c[128];
//	int s1c_num = 0, s2_1c_num = 0;
	int s2c_num = 0, s0c_num = 0;
	int s0_1c_num = 0;
	int free_count_ths = 0, free_count_ehs = 0;

	for(i=0 ; i < m_frame_len; i++){
		if((fi_local_[i].busy== SLOT_FREE || (!strict && fi_local_[i].sti==global_sti)) && !fi_local_[i].locker) {
			if (adj_ena_) {
				s2c[s2c_num++] = i;
//				if (i < m_frame_len/2)
//					s2_1c[s2_1c_num++] = i;

				if (fi_local_[i].count_3hop  == 0) {
					s0c[s0c_num++] = i;
//					s1c[s1c_num++] = i;
					if (i < m_frame_len/2)
						s0_1c[s0_1c_num++] = i;
				} else if (fi_local_[i].count_3hop < c3hop_threshold_ ){
//					s1c[s1c_num++] = i;
				}

			} else {
				s0c[s0c_num++] = i;
			}
		}
	}

	for(i=0 ; adj_frame_ena_ && i < m_frame_len; i++){
		if (fi_local_[i].busy== SLOT_FREE)
			free_count_ths++;
		if(fi_local_[i].busy== SLOT_FREE && fi_local_[i].count_3hop == 0)
			free_count_ehs++;
	}

	if (adj_frame_ena_&& m_frame_len > adj_frame_lower_bound_
					  &&  (((float)(m_frame_len - free_count_ehs))/m_frame_len) <= FRAMEADJ_CUT_RATIO_EHS
					  && (((float)(m_frame_len - free_count_ths))/m_frame_len) <= FRAMEADJ_CUT_RATIO_THS)
	{
		if (s0_1c_num != 0) {
			chosen_slot = m_uniformRandomVariable->GetInteger (0, s0_1c_num-1);
			return s0_1c[chosen_slot];
		}
	}

	if (testmode_init_flag_ && choose_bch_random_switch_ == 2) {
		testmode_init_flag_ = 0;
		switch (global_sti) {
		case 1: return 0;
		case 2: return 1;
		case 3: return 2;
		case 4: return 0;
		default: return global_sti -1;
		}
	}

	if (!adj_ena_) {
		if (s0c_num > 0) {
			chosen_slot = m_uniformRandomVariable->GetInteger (0, s0c_num-1);
			return s0c[chosen_slot];
		} else {

//	show_slot_occupation();
//	print_slot_status();

			return -1;
		}
	} else {
		if (/*strict &&*/ s0c_num >= adj_free_threshold_) {
			if (choose_bch_random_switch_) {
				chosen_slot = m_uniformRandomVariable->GetInteger (0, s0c_num-1);
			} else
				chosen_slot = 0;
			return s0c[chosen_slot];
		} else if (s2c_num != 0) {
			if (choose_bch_random_switch_)
				chosen_slot = m_uniformRandomVariable->GetInteger (0, s2c_num-1);
			else
				chosen_slot = 0;
			return s2c[chosen_slot];
		} else {

//	show_slot_occupation();
//	print_slot_status();

			return -1;
		}
	}

}

void
TdmaSatmac::Receive (Ptr<Packet> packet, const WifiMacHeader *hdr)
{
  if (hdr->IsSatmacData()) //TODO
  	{
      recvFI(packet);
  	} else
      ForwardUp (packet, hdr);
}

void
TdmaSatmac::ForwardUp (Ptr<Packet> packet, const WifiMacHeader *hdr)
{
  //NotifyRx(packet);
  m_upCallback (packet, hdr);
}


/**
 * 把收到的FI包解序列化后存到received_fi_list_中。
 */
void TdmaSatmac::recvFI(Ptr<Packet> p){
	unsigned int bit_pos=7, byte_pos=0;
 	unsigned long value=0;
	unsigned int recv_fi_frame_fi = 0;
	unsigned int i=0;
	unsigned int tmp_sti;

	//unsigned int bit_remain,index;
	Frame_info *fi_recv;
	satmac::FiHeader fihdr;
	//unsigned char buffer = p->accessdata();
	p->RemoveHeader(fihdr);

	value = fihdr.decode_value(byte_pos,bit_pos,BIT_LENGTH_STI);
	tmp_sti = (unsigned int)value;

	value = fihdr.decode_value(byte_pos,bit_pos,BIT_LENGTH_FRAMELEN);
	if (adj_frame_ena_)
		recv_fi_frame_fi = pow(2, value);
	else
		recv_fi_frame_fi = m_frame_len;
	
	fi_recv = this->get_new_FI(recv_fi_frame_fi);
	fi_recv->sti = tmp_sti;
	fi_recv->frame_len = recv_fi_frame_fi;
	fi_recv->recv_slot = this->slot_count_;
	//fi_recv->type = TYPE_FI;

	fi_recv->valid_time = this->m_frame_len;
	fi_recv->remain_time = fi_recv->valid_time;

//
//	for (int j = 0; j < tlen; j++)
//		printf("%x ", buffer[j]);
//	printf("\n");

	for(i=0; i<(unsigned int)recv_fi_frame_fi; i++){
		fihdr.decode_slot_tag(byte_pos, bit_pos, i, fi_recv);
	}

//	NS_LOG_DEBUG("slot "<<slot_count_<<" node "<<global_sti<<" recv a FI from node "<<fi_recv->sti<<": ");
//	for(i=0; i<(unsigned int)recv_fi_frame_fi; i++){
//		slot_tag* fi=fi_recv->slot_describe;
//		NS_LOG_DEBUG("|"<<fi[i].sti<<" b:"<<fi[i].busy<<" c:"<<fi[i].count_2hop);
//	}
#ifdef PRINT_SLOT_STATUS
	printf("Time: %ld  ", Simulator::Now().GetMicroSeconds());
	printf("slot %d, node %d recv a FI from node %d: ", slot_count_, global_sti, fi_recv->sti);
	for(i=0; i<(unsigned int)recv_fi_frame_fi; i++){
		slot_tag* fi=fi_recv->slot_describe;
		printf("|%d b:%d c:%d ", fi[i].sti, fi[i].busy, fi[i].count_2hop);
	}
	printf("\n");
#endif
	return;
}

void TdmaSatmac::merge_fi(Frame_info* base, Frame_info* append, Frame_info* decision){
	int count=0;
	slot_tag *fi_local_ = base->slot_describe;
	slot_tag *fi_append = append->slot_describe;
	slot_tag recv_tag;
	int recv_fi_frame_len = append->frame_len;

//	printf("I'm n%d, start merge fi from n %d\n", global_sti,append->sti);
	// status of our BCH should be updated first.
	for (count=0; count < m_frame_len; count++){
		recv_tag = fi_append[count];
		if (count == recv_fi_frame_len)
			break;
		
		if (fi_local_[count].sti == global_sti ) {//我自己的时隙
//			if (count != slot_num_ && count != slot_adj_candidate_) {
////				printf("I'm node %d, I recv a strange pkt..\n",global_sti);
//				continue;
//			}
			if (fi_local_[count].sti != recv_tag.sti && recv_tag.sti != 0) {//FI记录的id和我不一致
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
						} else if (recv_tag.psf == fi_local_[count].psf) {
							fi_local_[count].busy = SLOT_COLLISION;
						}
						break;
					case SLOT_2HOP:
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_FREE:
						//出现了隐藏站
						fi_local_[count].busy = SLOT_COLLISION;
						break;
					case SLOT_COLLISION:
						fi_local_[count].life_time = slot_lifetime_frame_;
						fi_local_[count].sti = recv_tag.sti;
						fi_local_[count].count_2hop = 1;
						fi_local_[count].count_3hop = 1;
						fi_local_[count].busy = SLOT_2HOP;
						break;
				}
			} else if (fi_local_[count].sti == recv_tag.sti){ //FI记录的id和我一致
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
//						if (recv_tag.count_2hop > 1)
//							fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_2HOP:
//						//出现了隐藏站
//						fi_local_[count].busy = SLOT_COLLISION;
						break;
					case SLOT_FREE:
						//出现了隐藏站
						fi_local_[count].busy = SLOT_COLLISION;
						break;
					case SLOT_COLLISION:
						break;
				}
			} else { //STI-slot == 0
				if (recv_tag.busy == SLOT_FREE) {
					if (!isNewNeighbor(append->sti)) {
						//出现了隐藏站
						fi_local_[count].busy = SLOT_COLLISION;
					}
				} else {
					//error state.
				}
			}
		}
	}

	//遍历每一个时隙
	for (count=0; count < ((recv_fi_frame_len > m_frame_len)?recv_fi_frame_len:m_frame_len); count++){
		if (count == recv_fi_frame_len)
			break;

		if (count >= m_frame_len ) {
			if (fi_local_[count].sti != 0)
				printf("merge_fi: node %d Protocol ERROR!!\n", global_sti);
		}

 		if (fi_local_[count].locker == 1)
			continue;

		//merge the recv_tag to fi_local_[slot_pos]
		recv_tag = fi_append[count];
		if (fi_local_[count].sti == global_sti || recv_tag.sti == global_sti)
			continue;
		else if (fi_local_[count].busy == SLOT_1HOP && fi_local_[count].sti != global_sti) {//直接邻居占用
			if (fi_local_[count].sti != recv_tag.sti && recv_tag.sti != 0) {
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
							} else if (recv_tag.psf == fi_local_[count].psf) {
								fi_local_[count].life_time = slot_lifetime_frame_;
								fi_local_[count].busy = SLOT_COLLISION;
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
					case SLOT_COLLISION:
						fi_local_[count].life_time = slot_lifetime_frame_;
						fi_local_[count].sti = recv_tag.sti;
						fi_local_[count].count_2hop = 1;
						fi_local_[count].count_3hop = 1;
						fi_local_[count].busy = SLOT_2HOP;
						break;
				}
			} else if (fi_local_[count].sti == recv_tag.sti){ //FI记录的id和我一致
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						if (recv_tag.sti == append->sti) { //FI发送者是该时隙的占有者
								fi_local_[count].life_time = slot_lifetime_frame_;
							if (fi_local_[count].c3hop_flag == 0) {
								fi_local_[count].count_2hop ++;
								fi_local_[count].count_3hop += recv_tag.count_2hop;
								fi_local_[count].c3hop_flag = 1;
							}
						} else {
							fi_local_[count].existed = 1;
							// do nothing.
						}

						break;
					case SLOT_2HOP:
					case SLOT_FREE:
					case SLOT_COLLISION:
						break;
				}
			} else { //STI-slot == 0
				if (append->sti == fi_local_[count].sti) {
					fi_local_[count].life_time = 0;
					fi_local_[count].sti = 0;
					fi_local_[count].count_2hop = 0;
					fi_local_[count].count_3hop = 0;
					fi_local_[count].busy = SLOT_FREE;
					fi_local_[count].locker = 1;
 				}
			}
		}else if (fi_local_[count].busy == SLOT_2HOP) {//两跳邻居占用
			if (fi_local_[count].sti != recv_tag.sti && recv_tag.sti != 0) {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						fi_local_[count].count_2hop ++;
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_2HOP:
					case SLOT_FREE:
						break;
					case SLOT_COLLISION:
						fi_local_[count].life_time = slot_lifetime_frame_;
						fi_local_[count].sti = recv_tag.sti;
						fi_local_[count].count_2hop = 1;
						fi_local_[count].count_3hop = 1;
						fi_local_[count].busy = SLOT_2HOP;
						break;
				}	
			} else if (fi_local_[count].sti == recv_tag.sti){ //FI记录的id和我一致
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						if (recv_tag.sti == append->sti) { //FI发送者是该时隙的占有者
							fi_local_[count].busy = SLOT_1HOP;
							fi_local_[count].life_time = slot_lifetime_frame_;
							if (fi_local_[count].c3hop_flag == 0) {
								fi_local_[count].c3hop_flag = 1;
								fi_local_[count].count_2hop ++;
								fi_local_[count].count_3hop += recv_tag.count_2hop;
							}
						} else {
							fi_local_[count].life_time = slot_lifetime_frame_;
							if (fi_local_[count].c3hop_flag == 0) {
								fi_local_[count].c3hop_flag = 1;
								fi_local_[count].count_2hop ++;
								fi_local_[count].count_3hop += recv_tag.count_2hop;
							}
						}
						break;
					case SLOT_2HOP:
					case SLOT_FREE:
					case SLOT_COLLISION:		
						break;
				}				
			} else { //STI-slot == 0
				if (append->sti == fi_local_[count].sti) {
					fi_local_[count].life_time = 0;
					fi_local_[count].sti = 0;
					fi_local_[count].count_2hop = 0;
					fi_local_[count].count_3hop = 0;
					fi_local_[count].busy = SLOT_FREE;
					fi_local_[count].locker = 1;
				}
			}
		} else if (fi_local_[count].busy == SLOT_FREE && fi_local_[count].sti == 0){ //空闲时隙
			if (fi_local_[count].sti != recv_tag.sti) {
				switch (recv_tag.busy)
				{
					case SLOT_1HOP:
						fi_local_[count].life_time = slot_lifetime_frame_;
						fi_local_[count].sti = recv_tag.sti;
						fi_local_[count].count_2hop = 1;
						fi_local_[count].count_3hop = recv_tag.count_2hop;
						fi_local_[count].c3hop_flag = 1;
						if (recv_tag.sti == append->sti) { //FI发送者是该时隙的占有者
							fi_local_[count].busy = SLOT_1HOP;
						} else {
							fi_local_[count].busy = SLOT_2HOP;						
						}
						break;
					case SLOT_2HOP:
						fi_local_[count].count_3hop += recv_tag.count_2hop;
						break;
					case SLOT_FREE:
						break;
					case SLOT_COLLISION:
						fi_local_[count].life_time = slot_lifetime_frame_;
						fi_local_[count].sti = recv_tag.sti;
						fi_local_[count].count_2hop = 1;
						fi_local_[count].count_3hop = 1;
						fi_local_[count].busy = SLOT_2HOP;
						break;
				}	
			}
		}

		if (count >= m_frame_len && fi_local_[count].sti != 0) {
			NS_LOG_DEBUG("I'm node "<<global_sti<<" I restore frame len from "<<m_frame_len<<" to "<<recv_fi_frame_len);
			m_frame_len = recv_fi_frame_len;
		}
	}
	return;
}

bool TdmaSatmac::isSingle(void) {
	slot_tag *fi_local = this->collected_fi_->slot_describe;
	int count;
	for (count=0; count < m_frame_len; count++){
		if (fi_local[count].sti != 0 && fi_local[count].sti != global_sti)
			return false;
	}
	return true;
}

/*
 * reduce the remain_time of each of received_fi_list_
 * if the argument time ==0 then clear the received_fi_list_;
 */
void TdmaSatmac::fade_received_fi_list(int time){
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
void TdmaSatmac::synthesize_fi_list(){
	Frame_info * processing_fi = received_fi_list_;
	int count;
	slot_tag *fi_local = this->collected_fi_->slot_describe;
	bool unlock_flag = 0;

	if (node_state_ != NODE_LISTEN && slot_memory_) {
		for (count=0; count < m_frame_len; count++){
			if (fi_local[count].locker && fi_local[count].sti != 0) {
				fi_local[count].locker = 0; //the locker must be locked in the last frame.

			} else if (fi_local[count].locker)
				unlock_flag = 1;

			if ((fi_local[count].sti == global_sti && (count == slot_num_ || count == slot_adj_candidate_))
					|| fi_local[count].sti == 0)
				continue;
			if (fi_local[count].life_time > 0)
				fi_local[count].life_time--;

			if (fi_local[count].life_time == 0) {
				if (fi_local[count].busy == SLOT_2HOP) {
					fi_local[count].busy = SLOT_FREE;
					fi_local[count].sti = 0;
					fi_local[count].count_2hop = 0;
					fi_local[count].count_3hop = 0;
					fi_local[count].psf = 0;
					fi_local[count].c3hop_flag = 0;
					fi_local[count].life_time = 0;
					fi_local[count].locker = 0;
				} else if (fi_local[count].busy == SLOT_1HOP && fi_local[count].existed == 1) {
					fi_local[count].busy = SLOT_2HOP;
					fi_local[count].life_time = slot_lifetime_frame_-1;
					fi_local[count].locker = 0;
				} else  {
					fi_local[count].busy = SLOT_FREE;
					fi_local[count].sti = 0;
					fi_local[count].count_2hop = 0;
					fi_local[count].count_3hop = 0;
					fi_local[count].psf = 0;
					fi_local[count].c3hop_flag = 0;
					fi_local[count].life_time = 0;
					fi_local[count].locker = 1; // lock the status for one frame.
				}

			} else if (fi_local[count].busy != SLOT_COLLISION
					&& fi_local[count].life_time == 0) {

				fi_local[count].busy = SLOT_FREE;
			}

			fi_local[count].existed = 0;
		}
	}

	while(processing_fi != NULL){
		merge_fi(this->collected_fi_, processing_fi, this->decision_fi_);
		processing_fi = processing_fi->next_fi;
	}

	if (unlock_flag) {
		for (count=0; count < m_frame_len; count++){
			if (fi_local[count].locker && fi_local[count].sti == 0) {
				fi_local[count].locker = 0; //the locker must be locked in the last frame.
			}
		}
	}
	
	print_slot_status();

}

bool TdmaSatmac::adjust_is_needed(int slot_num) {
	slot_tag *fi_collection = this->collected_fi_->slot_describe;
	int i,free_count_ths = 0, free_count_ehs = 0;

	int s0_1c_num = 0;

	for(i=0 ; i < m_frame_len; i++){
		if (fi_collection[i].busy== SLOT_FREE)
			free_count_ths++;
		if(fi_collection[i].busy== SLOT_FREE && fi_collection[i].count_3hop == 0) {
			free_count_ehs++;
			if (i < m_frame_len/2)
				s0_1c_num++;
		}
	}

	if (adj_ena_ && fi_collection[slot_num].count_3hop >= c3hop_threshold_ && free_count_ehs >= adj_free_threshold_) {
		return true;
	} else if (adj_frame_ena_ && slot_num >= m_frame_len/2
			&& m_frame_len > adj_frame_lower_bound_
			&& (((float)(m_frame_len - free_count_ehs))/m_frame_len) <= FRAMEADJ_CUT_RATIO_EHS
			&& (((float)(m_frame_len - free_count_ths))/m_frame_len) <= FRAMEADJ_CUT_RATIO_THS
			&& s0_1c_num != 0)
		return true;
	else
		return false;
}


void TdmaSatmac::adjFrameLen()
{
	if (!adj_frame_ena_)
		return;
	//calculate slot utilization
	int i;
	int free_count_ths = 0, free_count_ehs = 0;
	float utilrate_ths, utilrate_ehs;
	bool cutflag = true;
	slot_tag *fi_local_= this->collected_fi_->slot_describe;
	for(i=0 ; i < m_frame_len; i++){
		if(fi_local_[i].busy != SLOT_FREE) {
			if (i >= m_frame_len/2)
				cutflag = false;
		}
		if (fi_local_[i].busy== SLOT_FREE)
			free_count_ths++;
		if(fi_local_[i].busy== SLOT_FREE && fi_local_[i].count_3hop == 0)
			free_count_ehs++;
	}

	utilrate_ths = (float)(m_frame_len - free_count_ths)/m_frame_len;
	utilrate_ehs = (float)(m_frame_len - free_count_ehs)/m_frame_len;
	if (free_count_ths <= adj_free_threshold_)
		utilrate_ths = 1;
	if (free_count_ehs <= adj_free_threshold_)
		utilrate_ehs = 1;

	if (utilrate_ehs >= FRAMEADJ_EXP_RATIO && m_frame_len < adj_frame_upper_bound_) {
		m_frame_len *= 2;
	} else if (cutflag
			&& utilrate_ths <= FRAMEADJ_CUT_RATIO_THS
			&& utilrate_ehs <= FRAMEADJ_CUT_RATIO_EHS
			&& m_frame_len > adj_frame_lower_bound_) {
		m_frame_len /= 2;
	}

	switch (m_frame_len) {
	case 16:
		adj_free_threshold_ = 2;
		break;
	case 32:
		adj_free_threshold_ = 3;
		break;
	case 64:
		adj_free_threshold_ = 4;
		break;
	case 128:
		adj_free_threshold_ = 5;
		break;
	default:
		adj_free_threshold_ = 5;
	}

}


Time
TdmaSatmac::CalculateTxTime (Ptr<const Packet> packet)
{
  NS_LOG_FUNCTION (*packet);
  NS_ASSERT_MSG (packet->GetSize () < 1500,"PacketSize must be less than 1500B, it is: " << packet->GetSize ());
  return m_bps.CalculateBytesTxTime (packet->GetSize ());
}

void TdmaSatmac::generate_send_FI_packet(){
#ifdef PRINT_SLOT_STATUS
	std::cout<<"Time "<<Simulator::Now().GetMicroSeconds()<<" I'm node "<<global_sti<<" in slot "<<slot_count_<<", I send an FI"<<std::endl;
#endif
	slot_tag *fi_local_= this->collected_fi_->slot_describe;
	Ptr<Packet> p = Create<Packet> ();
	satmac::FiHeader fihdr(m_frame_len, global_sti, fi_local_);
	p->AddHeader (fihdr);
	WifiMacHeader wifihdr;
	wifihdr.SetType (WIFI_MAC_SATMAC);//TODO: add WIFI_MAC_SATMAC in wifi-mac-header, WifiMacType, settype ...
	wifihdr.SetAddr1 (Mac48Address::GetBroadcast());
	wifihdr.SetAddr2 (GetAddress ());
	if (m_wifimaclow_flag)
	{
		wifihdr.SetAddr3 (m_wifimaclow->GetAddress());
	} else
		wifihdr.SetAddr3 (m_low->GetAddress ());
	wifihdr.SetDsFrom ();
	wifihdr.SetDsNotTo ();

	if (m_wifimaclow_flag)
	{
		SendFiDown(p, wifihdr);
	} else {
		Time packetTransmissionTime = CalculateTxTime (p);
		m_slotRemainTime = m_slotTime - packetTransmissionTime.GetMicroSeconds ();

		NS_LOG_DEBUG ("FI TransmissionTime(microSeconds): " << packetTransmissionTime.GetMicroSeconds () << "usec");
		NS_ASSERT_MSG(packetTransmissionTime < MicroSeconds (m_slotTime), "FATAL: cannot transmit FI.");

		Simulator::Schedule (packetTransmissionTime, &TdmaSatmac::SendFiDown, this, p, wifihdr);
	}
}

void TdmaSatmac::WaitWifiState()
{
	if (m_transmissionListener->isTxok())
//	if (!(this->getWifiPhy()->IsStateTx ()) && !(this->getWifiPhy()->IsStateSwitching ()))
	{
		m_transmissionListener->setTxok(false);
		switch (this->node_state_)
		{
		case NODE_WORK_FI:
		case NODE_WORK_ADJ:
			StartTransmission(m_slotRemainTime);
			break;
		default: break;
		}
	} else {
		m_slotRemainTime -= 50;
		Simulator::Schedule (MicroSeconds(50), &TdmaSatmac::WaitWifiState, this);
	}
}

void
TdmaSatmac::SendFiDown (Ptr<Packet> packet, WifiMacHeader header)
{
  if (m_wifimaclow_flag)
  {
	  MacLowTransmissionParameters params;
	  params.DisableOverrideDurationId ();
	  params.DisableRts ();
	  params.DisableAck ();
	  params.DisableNextData ();
	  WifiTxVector txVector = this->getWifiMacLow()->GetDataTxVector (packet, &header);
	  Time txDuration = this->getWifiPhy()->CalculateTxDuration (this->getWifiMacLow()->GetSize (packet, &header), txVector, WIFI_PREAMBLE_LONG, this->getWifiPhy()->GetFrequency ());
//			  this->getWifiPhy()->CalculateTxDuration (packet->GetSize (), txVector, WIFI_PREAMBLE_LONG, this->getWifiPhy()->GetFrequency ());
//	  txDuration += this->getWifiMacLow()->GetSifs();
	  m_slotRemainTime -= txDuration.GetMicroSeconds();
	  m_wifimaclow->StartTransmission (packet,
	                                 &header,
	                                 params,
	                                 m_transmissionListener);
	  switch (this->node_state_)
	  {
	  case NODE_WORK_FI:
	  case NODE_WORK_ADJ:
		Simulator::Schedule (txDuration, &TdmaSatmac::StartTransmission, this,m_slotRemainTime);
	  	break;
	  default: break;
	  }
//	  WaitWifiState();
  } else {
	  m_low->StartTransmission (packet, &header);
	  NotifyTx (packet);
	  switch (this->node_state_)
	  {
		case NODE_WORK_FI:
		case NODE_WORK_ADJ:
			StartTransmission(m_slotRemainTime);
			break;
		default: break;
	  }
  }
  
}

void
TdmaSatmac::StartTransmission (uint64_t transmissionTimeUs)
{
  NS_LOG_DEBUG (transmissionTimeUs << " usec");
  Time totalTransmissionSlot = MicroSeconds (transmissionTimeUs);
  if (m_queue->IsEmpty ())
    {
      NS_LOG_DEBUG ("queue empty");
      return;
    }
  WifiMacHeader header;
  Ptr<const Packet> peekPacket = m_queue->Peek (&header);
  if (m_wifimaclow_flag)
  {
	  WifiTxVector txVector = this->getWifiMacLow()->GetDataTxVector (peekPacket, &header);
	  Time txDuration = this->getWifiPhy()->CalculateTxDuration (this->getWifiMacLow()->GetSize (peekPacket, &header), txVector, WIFI_PREAMBLE_LONG, this->getWifiPhy()->GetFrequency ());
//	  txDuration += this->getWifiMacLow()->GetSifs();
	  if (m_slotRemainTime >= txDuration.GetMicroSeconds())
	  {
		  m_slotRemainTime -= txDuration.GetMicroSeconds();
		  m_lastpktUsedTime = txDuration.GetMicroSeconds();
		  SendPacketDown(MicroSeconds(m_slotRemainTime));
	  } else {
//		  std::cout << "Packet takes more time to transmit than the slot allotted. Will send in next slot" << std::endl;
	  }
  } else {
	  Time packetTransmissionTime = CalculateTxTime (peekPacket);
	  m_lastpktUsedTime = packetTransmissionTime.GetMicroSeconds();
	  NS_LOG_DEBUG ("Packet TransmissionTime(microSeconds): " << packetTransmissionTime.GetMicroSeconds () << "usec");
	  if (packetTransmissionTime < totalTransmissionSlot)
		{
		  totalTransmissionSlot -= packetTransmissionTime;
		  m_slotRemainTime -= packetTransmissionTime.GetMicroSeconds ();
		  Simulator::Schedule (packetTransmissionTime, &TdmaSatmac::SendPacketDown, this,totalTransmissionSlot);
		}
	  else
		{
		  NS_LOG_DEBUG ("Packet takes more time to transmit than the slot allotted. Will send in next slot");
		}
  }
}

void
TdmaSatmac::SendPacketDown (Time remainingTime)
{
  WifiMacHeader header;
  Ptr<const Packet> packet = m_queue->Dequeue (&header);
  if (m_wifimaclow_flag)
  {
	  MacLowTransmissionParameters params;
//	  params.DisableOverrideDurationId ();
	  params.DisableRts ();

	  if (header.GetAddr1 ().IsGroup())
	  {
		  params.DisableAck();
	  } else
		  params.EnableAck ();
//	  params.DisableAck ();
//	  params.DisableNextData ();
	  header.SetDuration(MicroSeconds(m_lastpktUsedTime));
	  m_wifimaclow->StartTransmission (packet,
	                                 &header,
	                                 params,
	                                 m_transmissionListener);

//	  std::cout<<"satmac send a pkt Size "<<m_lastpktUsedTime <<" fromSti = " << this->GetGlobalSti()<<" to addr "<<header.GetAddr1 () << " from addr "<< header.GetAddr2 ()<< " Time "<< Simulator::Now().GetMicroSeconds()<< std::endl;
  } else
	  m_low->StartTransmission (packet, &header);
//  TxQueueStart (0);
  NotifyTx (packet);
//  TxQueueStart (0);
  if (m_wifimaclow_flag)
  {
//	  Time txDuration = this->getWifiMacLow()->GetLastPktTxDuration();
//	  m_slotRemainTime -=
	  Simulator::Schedule (MicroSeconds(m_lastpktUsedTime), &TdmaSatmac::StartTransmission, this,remainingTime.GetMicroSeconds ());
  } else
	  StartTransmission (remainingTime.GetMicroSeconds ());
}


void
TdmaSatmac::slotHandler ()
{
  NS_LOG_FUNCTION_NOARGS ();
  slot_tag *fi_collection = this->collected_fi_->slot_describe;
  // Restart timer for next slot.
  total_slot_count_ = total_slot_count_+1;
  slot_count_ = total_slot_count_ %  m_frame_len;
  Simulator::Schedule (GetSlotTime(), &TdmaSatmac::slotHandler, this);
  initialed_ = true;

//  std::cout<<"Start time:" << Simulator::Now().GetMicroSeconds() << std::endl;

  m_slotRemainTime = m_slotTime;

  slot_state_ = BEGINING;

  this->fade_received_fi_list(1);
/*
  if(this->enable == 0){
	  double x,y,z;
	  ((CMUTrace *)this->downtarget_)->getPosition(&x,&y,&z);
	  if(z == 0){
		  this->enable = 1;
		  slot_num_ = (slot_count_+1)% m_frame_len; //slot_num_初始化为当前的下一个时隙。
	  }
  }
  else if(this->enable == 1){
	  double x,y,z;
	  ((CMUTrace *)this->downtarget_)->getPosition(&x,&y,&z);
	  if(z > 0 ){
		  this->enable = 0;
		  //slot_num_ = (slot_count_+1)% m_frame_len;
	  }
  }
*/
//TODO: 加一个开启的命令。。
//  if(this->enable == 0){
//	  return;
//  }

  if (Simulator::Now().GetMilliSeconds() - last_log_time_.GetMilliSeconds() >= 1000) {
	  last_log_time_ = Simulator::Now();

	  /**
	   * LPF
	   */
      std::ofstream out (m_traceOutFile, std::ios::app);
      out << "m "<<(Simulator::Now ()).GetMilliSeconds ()<<" t["<<slot_num_<<"] _"<<global_sti<<
	  	"_ LPF "<<waiting_frame_count<<" "<<request_fail_times<<" "<<collision_count_<<" "<<
	  	frame_count_<<" "<<continuous_work_fi_max_<<" "<<adj_count_success_<<" "<<
	  	adj_count_total_<<" "<<safe_send_count_<<" "<<safe_recv_count_<<" "<<
	  	no_avalible_count_<<" "<<slot_num_<<" "<<m_frame_len<<" "<<localmerge_collision_count_
	  	<< std::endl;
	  out.close ();
  }


  NS_ASSERT_MSG (slot_num_ <= m_frame_len, "FATAL! slot_num_ > m_frame_len" << this->GetGlobalSti());
  
  if (slot_count_ == slot_num_){
	  frame_count_++;
	  switch (node_state_) {
	  case NODE_INIT:// the first whole slot of a newly initialized node, it begin to listen
		  node_state_ = NODE_LISTEN;
		  waiting_frame_count =0;
		  request_fail_times = 0;
		  collision_count_ = 0;
		  continuous_work_fi_ = 0;
		  continuous_work_fi_max_ = 0;
		  adj_count_success_ = 0;
		  adj_count_total_ = 0;
		  last_log_time_ = Simulator::Now();
		  no_avalible_count_ = 0;
		  backoff_frame_num_ = 0;
		  return;
	  case NODE_LISTEN:
		  waiting_frame_count++;

		  if (backoff_frame_num_) {
//			  printf("%d : %d\n",global_sti,backoff_frame_num_);
			  backoff_frame_num_--;
			  return;
		  }

		  //根据自己的fi-local，决定自己要申请的slot，修改自己的slot_num_
		  this->clear_FI(this->collected_fi_); //初始化
		  fi_collection = this->collected_fi_->slot_describe;
		  synthesize_fi_list();
		  slot_num_ = determine_BCH(0);
		  if(slot_num_ < 0){
			  node_state_ = NODE_LISTEN;
			  slot_num_ = slot_count_;
			  no_avalible_count_++;
			  backoff_frame_num_ = m_uniformRandomVariable->GetInteger (0, 20);
#ifdef PRINT_SLOT_STATUS
				printf("I'm node %d, in slot %d, NODE_LISTEN and I cannot choose a BCH!!\n", global_sti, slot_count_);
#endif
			  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_LISTEN and I cannot choose a BCH!!");

			  return;
		  }
#ifdef PRINT_SLOT_STATUS
			printf("I'm node %d, in slot %d, NODE_LISTEN, choose: %d\n", global_sti, slot_count_, slot_num_);
#endif
		  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_LISTEN, choose: "<<slot_num_);

		  //如果正好决定的时隙就是本时隙，那么直接发送
		  if(slot_num_== slot_count_){
			  fi_collection[slot_count_].busy = SLOT_1HOP;
			  fi_collection[slot_count_].sti = global_sti;
			  fi_collection[slot_count_].count_2hop = 1;
			  fi_collection[slot_count_].count_3hop = 1;
			  fi_collection[slot_count_].psf = 0;
			  generate_send_FI_packet(); //必须在BCH状态设置完之后调用。
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
		  if (!slot_memory_) {
			  this->clear_others_slot_status();
			  fi_collection = this->collected_fi_->slot_describe;
		  }
		  synthesize_fi_list();
		  if((fi_collection[slot_count_].sti == global_sti && fi_collection[slot_count_].busy == SLOT_1HOP)
				  || fi_collection[slot_count_].sti == 0) {
			  fi_collection[slot_count_].busy = SLOT_1HOP;
			  fi_collection[slot_count_].sti = global_sti;
			  fi_collection[slot_count_].count_2hop = 1;
			  fi_collection[slot_count_].count_3hop = 1;
			  fi_collection[slot_count_].psf = 0;
			  generate_send_FI_packet();
			  node_state_ = NODE_REQUEST;
			  return;
		  } else {
			  if (fi_collection[slot_count_].sti == global_sti) {
				  fi_collection[slot_count_].busy = SLOT_FREE;
				  fi_collection[slot_count_].sti = 0;
				  fi_collection[slot_count_].count_2hop = 0;
				  fi_collection[slot_count_].count_3hop = 0;
				  fi_collection[slot_count_].psf = 0;
				  fi_collection[slot_count_].locker = 1;
			  }
			  request_fail_times++;


			  slot_num_ = determine_BCH(0);
			  if(slot_num_ < 0 || slot_num_== slot_count_){
				  node_state_ = NODE_LISTEN;
				  no_avalible_count_ ++;
				  backoff_frame_num_ = m_uniformRandomVariable->GetInteger (0, 20);
				  slot_num_ = slot_count_;
				  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_WAIT_REQUEST and I cannot choose a BCH!!");
#ifdef PRINT_SLOT_STATUS
					printf("I'm node %d, in slot %d, NODE_WAIT_REQUEST and I cannot choose a BCH!!\n", global_sti, slot_count_);
#endif
				  return;
			  }
#ifdef PRINT_SLOT_STATUS
				printf("I'm node %d, in slot %d, NODE_WAIT_REQUEST and current bch is unvalid, choose: %d\n", global_sti, slot_count_, slot_num_);
#endif
			  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_WAIT_REQUEST and current bch is unvalid, choose: "<<slot_num_);
			  node_state_ = NODE_WAIT_REQUEST;
			  return;
		  }
		  break;
	  case NODE_REQUEST:// or node_state_ = NODE_WORK;;
		  if (!slot_memory_) {
			  this->clear_others_slot_status();
			  fi_collection = this->collected_fi_->slot_describe;
		  }
		  synthesize_fi_list();
		  if((fi_collection[slot_count_].sti == global_sti && fi_collection[slot_count_].busy == SLOT_1HOP)
				  || fi_collection[slot_count_].sti == 0) {

			  node_state_ = NODE_WORK_FI;

			  generate_send_FI_packet();
		  } else {
			  waiting_frame_count++;
			  if (fi_collection[slot_count_].sti == global_sti) {
				  fi_collection[slot_count_].busy = SLOT_FREE;
				  fi_collection[slot_count_].sti = 0;
				  fi_collection[slot_count_].count_2hop = 0;
				  fi_collection[slot_count_].count_3hop = 0;
				  fi_collection[slot_count_].psf = 0;
				  fi_collection[slot_count_].locker = 1;
			  }

			  request_fail_times++;

			  slot_num_ = determine_BCH(0);
			  if(slot_num_ < 0 || slot_num_== slot_count_){
				  node_state_ = NODE_LISTEN;
				  no_avalible_count_ ++;
				  backoff_frame_num_ = m_uniformRandomVariable->GetInteger (0, 20);
				  slot_num_ = slot_count_;
#ifdef PRINT_SLOT_STATUS
					printf("I'm node %d, in slot %d, NODE_REQUEST and I cannot choose a BCH!!\n", global_sti, slot_count_);
#endif
				  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_REQUEST and I cannot choose a BCH!!");
				  return;
			  }
#ifdef PRINT_SLOT_STATUS
				printf("I'm node %d, in slot %d, NODE_REQUEST and current bch is unvalid, choose: %d\n", global_sti, slot_count_, slot_num_);
#endif
			  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_REQUEST and current bch is unvalid, choose: "<<slot_num_);
			  node_state_ = NODE_WAIT_REQUEST;
			  return;
		  }
		  break;
	  case NODE_WORK_FI:
		  if (!slot_memory_) {
			  this->clear_others_slot_status();
			  fi_collection = this->collected_fi_->slot_describe;
		  }
		  synthesize_fi_list();

		  if((fi_collection[slot_count_].sti == global_sti && fi_collection[slot_count_].busy == SLOT_1HOP)
				  || fi_collection[slot_count_].sti == 0)//BCH可用
		  {
			  continuous_work_fi_ ++;
			  continuous_work_fi_max_ = (continuous_work_fi_max_ > continuous_work_fi_)?continuous_work_fi_max_:continuous_work_fi_;
			  if (adjust_is_needed(slot_num_)) {
				  slot_adj_candidate_ = determine_BCH(1);
				  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_WORK_FI ADJ is needed! choose: "<<slot_adj_candidate_);
				  if (slot_adj_candidate_ >= 0) {
					  if (adj_single_slot_ena_) {
						  node_state_ = NODE_WORK_FI;
						  adj_count_success_++;
						  slot_num_ = slot_adj_candidate_;
						  fi_collection[slot_count_].busy = SLOT_FREE;
						  fi_collection[slot_count_].sti = 0;
						  fi_collection[slot_count_].count_2hop = 0;
						  fi_collection[slot_count_].count_3hop = 0;
						  fi_collection[slot_count_].psf = 0;
						  fi_collection[slot_count_].locker = 0;

						  fi_collection[slot_num_].busy = SLOT_1HOP;
						  fi_collection[slot_num_].sti = global_sti;
						  fi_collection[slot_num_].count_2hop = 1;
						  fi_collection[slot_num_].count_3hop = 1;
						  fi_collection[slot_num_].psf = 0;
					  } else {
						  node_state_ = NODE_WORK_ADJ;
						  adj_count_total_++;
						  fi_collection[slot_adj_candidate_].busy = SLOT_1HOP;
						  fi_collection[slot_adj_candidate_].sti = global_sti;
						  fi_collection[slot_adj_candidate_].count_2hop = 1;
						  fi_collection[slot_adj_candidate_].count_3hop = 1;
						  fi_collection[slot_adj_candidate_].psf = 0;
					  }
				  }
			  } else
				  adjFrameLen();
			  generate_send_FI_packet();

			  if (random_bch_if_single_switch_ && isSingle()) {
				  if (bch_slot_lock_-- == 0) {
					  slot_num_ = determine_BCH(0);
					  fi_collection[slot_count_].busy = SLOT_FREE;
					  fi_collection[slot_count_].sti = 0;
					  fi_collection[slot_count_].count_2hop = 0;
					  fi_collection[slot_count_].count_3hop = 0;
					  fi_collection[slot_count_].psf = 0;
					  fi_collection[slot_count_].locker = 1;

					  fi_collection[slot_num_].busy = SLOT_1HOP;
					  fi_collection[slot_num_].sti = global_sti;
					  fi_collection[slot_num_].count_2hop = 1;
					  fi_collection[slot_num_].count_3hop = 1;
					  fi_collection[slot_num_].psf = 0;

					  bch_slot_lock_ = 5;
				  }
			  } else
				  bch_slot_lock_ = 5;

		  } else {
			  continuous_work_fi_ = 0;
			  if (fi_collection[slot_count_].sti == global_sti) {
				  fi_collection[slot_count_].busy = SLOT_FREE;
				  fi_collection[slot_count_].sti = 0;
				  fi_collection[slot_count_].count_2hop = 0;
				  fi_collection[slot_count_].count_3hop = 0;
				  fi_collection[slot_count_].psf = 0;
				  fi_collection[slot_count_].locker = 1;
			  }

			  collision_count_++;

			  slot_num_ = determine_BCH(0);
			  if(slot_num_ < 0 || slot_num_== slot_count_){
				  node_state_ = NODE_LISTEN;
				  slot_num_ = slot_count_;
				  no_avalible_count_ ++;
				  backoff_frame_num_ = m_uniformRandomVariable->GetInteger (0, 20);
				  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_WORK_FI and I cannot choose a BCH!!");
				  return;
			  }

			  NS_LOG_DEBUG("I'm node "<<global_sti<<", in slot "<<slot_count_<<", NODE_WORK_FI and current bch is unvalid, choose: "<<slot_num_);
			  node_state_ = NODE_WAIT_REQUEST;
			  return;
		  }
		  break;
	  case NODE_WORK_ADJ:
		  if (!slot_memory_) {
			  this->clear_others_slot_status();
			  fi_collection = this->collected_fi_->slot_describe;
		  }
		  synthesize_fi_list();
		  if((fi_collection[slot_count_].sti == global_sti && fi_collection[slot_count_].busy == SLOT_1HOP)
				  || fi_collection[slot_count_].sti == 0)//BCH依然可用
		  {
			  if ((fi_collection[slot_count_].count_3hop >= fi_collection[slot_adj_candidate_].count_3hop)
					  && ((fi_collection[slot_adj_candidate_].sti == global_sti && fi_collection[slot_adj_candidate_].busy == SLOT_1HOP)
							  || fi_collection[slot_adj_candidate_].sti == 0)) //ADJ时隙可用)
			  {
				  int oldbch = slot_num_;
				  node_state_ = NODE_WORK_FI;
				  slot_num_ = slot_adj_candidate_;
				  adj_count_success_++;
				  fi_collection[oldbch].busy = SLOT_FREE;
				  fi_collection[oldbch].sti = 0;
				  fi_collection[oldbch].count_2hop = 0;
				  fi_collection[oldbch].count_3hop = 0;
				  fi_collection[oldbch].psf = 0;
				  fi_collection[oldbch].locker = 1;
			  } else {
				  node_state_ = NODE_WORK_FI;
				  fi_collection[slot_adj_candidate_].busy = SLOT_FREE;
				  fi_collection[slot_adj_candidate_].sti = 0;
				  fi_collection[slot_adj_candidate_].count_2hop = 0;
				  fi_collection[slot_adj_candidate_].count_3hop = 0;
				  fi_collection[slot_adj_candidate_].psf = 0;
				  fi_collection[slot_adj_candidate_].locker = 1;
			  }

			  generate_send_FI_packet();
		  } else { //BCH已经不可用

			  if((fi_collection[slot_adj_candidate_].sti == global_sti && fi_collection[slot_adj_candidate_].busy == SLOT_1HOP)
					  || fi_collection[slot_adj_candidate_].sti == 0) { //ADJ时隙可用
				  node_state_ = NODE_WORK_FI;
				  adj_count_success_++;
				  slot_num_ = slot_adj_candidate_;
			  } else { //ADJ时隙不可用
				  collision_count_++;

				  if (fi_collection[slot_adj_candidate_].sti == global_sti) {
					  fi_collection[slot_adj_candidate_].busy = SLOT_FREE;
					  fi_collection[slot_adj_candidate_].sti = 0;
					  fi_collection[slot_adj_candidate_].count_2hop = 0;
					  fi_collection[slot_adj_candidate_].count_3hop = 0;
					  fi_collection[slot_adj_candidate_].psf = 0;
					  fi_collection[slot_adj_candidate_].locker = 1;
				  }
				  slot_num_ = determine_BCH(0);
				  if(slot_num_ < 0 || slot_num_== slot_count_){
					  node_state_ = NODE_LISTEN;
					  slot_num_ = slot_count_;
					  no_avalible_count_ ++;
					  backoff_frame_num_ = m_uniformRandomVariable->GetInteger (0, 20);
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

  return;

}

} // namespace ns3
