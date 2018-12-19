#ifndef TDMA_SATMAC_H
#define TDMA_SATMAC_H

#include "ns3/data-rate.h"
#include "ns3/nstime.h"
#include "tdma-mac.h"
#include "tdma-mac-low.h"
#include "tdma-mac-queue.h"
#include "satmac-common.h"
#include "ns3/random-variable-stream.h"
#include "ns3/mac-low.h"
#include "ns3/dca-txop.h"
#include "ns3/wifi-phy.h"
#include <string>

namespace ns3 {

class WifiMacHeader;
class TdmaMacLow;
class TdmaMac;
class RegularWifiMac;
class MacLow;

class TransmissionListenerUseless : public MacLowTransmissionListener
{
public:
  /**
   * Create a TransmissionListener for the given DcaTxop.
   *
   * \param txop
   */
	TransmissionListenerUseless ():txok(false)
  {
  }

  virtual ~TransmissionListenerUseless ()
  {
  }

  virtual void GotCts (double snr, WifiMode txMode)
  {

  }
  virtual void MissedCts (void)
  {

  }
  virtual void GotAck (double snr, WifiMode txMode)
  {

  }
  virtual void MissedAck (void)
  {

  }
  virtual void StartNextFragment (void)
  {
  }
  virtual void StartNext (void)
  {
  }
  virtual void Cancel (void)
  {
  }
  virtual void EndTxNoAck (void);

	bool isTxok() const {
		return txok;
	}

	void setTxok(bool txok) {
		this->txok = txok;
	}

private:
  bool txok;

};

class TdmaSatmac : public TdmaMac
{
public:
  static TypeId GetTypeId (void);

  TdmaSatmac ();
  ~TdmaSatmac ();


  // inherited from TdmaMac.
  virtual void Enqueue (Ptr<const Packet> packet, Mac48Address to, Mac48Address from);
  virtual void Enqueue (Ptr<const Packet> packet, Mac48Address to);
  virtual void Enqueue (Ptr<const Packet> packet, WifiMacHeader hdr);
  virtual bool SupportsSendFrom (void) const;
  virtual void SetForwardUpCallback (Callback<void, Ptr<Packet>, const WifiMacHeader*> upCallback);
  virtual void SetLinkUpCallback (Callback<void> linkUp);
  virtual void SetLinkDownCallback (Callback<void> linkDown);
  virtual Mac48Address GetAddress (void) const;
  virtual Ssid GetSsid (void) const;
  virtual void SetAddress (Mac48Address address);
  virtual void SetSsid (Ssid ssid);
  virtual Mac48Address GetBssid (void) const;
  virtual void SetDevice (Ptr<TdmaNetDevice> device);
  virtual Ptr<TdmaNetDevice> GetDevice (void) const;
  virtual void NotifyTx (Ptr<const Packet> packet);
  virtual void NotifyTxDrop (Ptr<const Packet> packet);
  virtual void NotifyRx (Ptr<const Packet> packet);
  virtual void NotifyPromiscRx (Ptr<const Packet> packet);
  virtual void NotifyRxDrop (Ptr<const Packet> packet);
  virtual void SetTxQueueStartCallback (Callback<bool,uint32_t> queueStart);
  virtual void SetTxQueueStopCallback (Callback<bool,uint32_t> queueStop);
  virtual uint32_t GetQueueState (uint32_t index);
  virtual uint32_t GetNQueues (void);
  virtual void Initialize (void);

  void Receive (Ptr<Packet> packet, const WifiMacHeader *hdr);
  /**
   * \param packet packet to send
   * \param hdr header of packet to send.
   *
   * Store the packet in the internal queue until it
   * can be sent safely.
   */
  void Queue (Ptr<const Packet> packet, const WifiMacHeader &hdr);
  void SetMaxQueueSize (uint32_t size);
  void SetMaxQueueDelay (Time delay);
  Ptr<SimpleWirelessChannel> GetChannel (void) const;
  Ptr<TdmaMacLow> GetTdmaMacLow (void) const;
  void RequestForChannelAccess (void);

  void StartTransmission (uint64_t transmissionTime);
  /**
   * \param slotTime the duration of a slot.
   *
   * It is a bad idea to call this method after RequestAccess or
   * one of the Notify methods has been invoked.
   */
  void SetSlotTime (Time slotTime);
  /**
   */
  void SetGuardTime (Time guardTime);
  /**
   */
  void SetDataRate (DataRate bps);

  /**
   */
  void SetInterFrameTimeInterval (Time interFrameTime);
  /**
   */
  Time GetSlotTime (void) const;
  /**
   */
  Time GetGuardTime (void) const;
  /**
   */
  DataRate GetDataRate (void) const;
  /**
   */
  Time GetInterFrameTimeInterval (void) const;

  void SetGlobalSti(int sti);
  int GetGlobalSti(void) const;

  void SetFrameLen(int framelen);
  int GetFrameLen(void) const;

  void SetSlotLife(int slotlife_perframe);
  int GetSlotLife(void) const;

  void SetC3HThreshold(int c3h_threshold);
  int GetC3HThreshold(void) const;

  void SetAdjThreshold(int adj_threshold);
  int GetAdjThreshold(void) const;

  void SetRandomBchIfSingle(int flag);
  int GetRandomBchIfSingle(void) const;

  int getChooseBchRandomSwitch() const;
  void setChooseBchRandomSwitch(int chooseBchRandomSwitch);

  void SetAdjEnable(int flag);
  int GetAdjEnable(void) const;

  void SetAdjFrameEnable(int flag);
  int GetAdjFrameEnable(void) const;

  void SetAdjFrameLowerBound(int lowerbound);
  int GetAdjFrameLowerBound(void) const;
  
  void SetAdjFrameUpperBound(int upperbound);
  int GetAdjFrameUpperBound(void) const;

  void SetSlotMemory(int flag);
  int GetSlotMemory(void) const;
  
  void StartTdmaSessions (void);
  void SetChannel (Ptr<SimpleWirelessChannel> c);
  virtual void Start (void);

  Time CalculateTxTime (Ptr<const Packet> packet);

	Ptr<MacLow> getWifiMacLow() const {
		return m_wifimaclow;
	}

	void setWifiMacLow(const Ptr<MacLow> wifimaclow) {
		m_wifimaclow = wifimaclow;
	}

	int getWifimaclowFlag() const {
		return m_wifimaclow_flag;
	}

	void setWifimaclowFlag(int wifimaclowFlag) {
		m_wifimaclow_flag = wifimaclowFlag;
	}
	Ptr<WifiPhy>
	getWifiPhy () const
	{
		return m_wifiphy;
	}

	void
	setWifiPhy (Ptr<WifiPhy> phy)
	{
		m_wifiphy = phy;
	}


private:
  static Time GetDefaultSlotTime (void);
  static Time GetDefaultGuardTime (void);
  static DataRate GetDefaultDataRate (void);
  static int GetDefaultFrameLen(void) ;
  static int GetDefaultSlotLife(void) ;
  static int GetDefaultC3HThreshold(void) ;
  static int GetDefaultAdjThreshold(void) ;
  static int GetDefaultRandomBchIfSingle(void) ;
  static int GetDefaultChooseBchRandomSwitch(void);
  static int GetDefaultAdjEnable(void) ;
  static int GetDefaultAdjFrameEnable(void) ;
  static int GetDefaultAdjFrameLowerBound(void) ;
  static int GetDefaultAdjFrameUpperBound(void) ;
  static int GetDefaultSlotMemory(void) ;
  

  void ForwardUp  (Ptr<Packet> packet, const WifiMacHeader *hdr);
  void TxOk (const WifiMacHeader &hdr);
  void TxFailed (const WifiMacHeader &hdr);
  virtual void DoDispose (void);
//  virtual void DoInitialize (void);
  TdmaSatmac (const TdmaSatmac & ctor_arg);
  TdmaSatmac &operator = (const TdmaSatmac &o);
  void TxQueueStart (uint32_t index);
  void TxQueueStop (uint32_t index);
  void SendPacketDown (Time remainingTime);
  void SendFiDown (Ptr<Packet> packet, WifiMacHeader hdr);

  void WaitWifiState(void);

  
  /*
   * slot_tag and fi handle functions
   */
  void slotHandler ();
  /* Determining which slot will be selected as BCH. */
  int determine_BCH(bool strict);
  void show_slot_occupation(void);
  void recvFI(Ptr<Packet> p);

  //void clear_Local_FI(int begin_slot, int end_slot, int slot_num);
  /* Translating the fi_local_ to a FI_packet transmitted */
  unsigned char* generate_Slot_Tag_Code(slot_tag *st);
  //void update_slot_tag(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, unsigned long long recv_sti);
  //void set_cetain_slot_tag(int index, unsigned char busy,unsigned long long sti, unsigned char psf, unsigned char ptp);
  void generate_send_FI_packet();

  //void update_slot_tag(unsigned char* buffer,unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, unsigned int recv_sti);
  Frame_info * get_new_FI(int slot_count);
  void fade_received_fi_list(int time);
  bool isNewNeighbor(int sid);
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
  void print_slot_status(void);
  /**
   * The trace source fired when packets come into the "top" of the device
   * at the L3/L2 transition, before being queued for transmission.
   *
   * \see class CallBackTraceSource
   */
  TracedCallback<Ptr<const Packet> > m_macTxTrace;

  /**
   * The trace source fired when packets coming into the "top" of the device
   * are dropped at the MAC layer during transmission.
   *
   * \see class CallBackTraceSource
   */
  TracedCallback<Ptr<const Packet> > m_macTxDropTrace;

  /**
   * The trace source fired for packets successfully received by the device
   * immediately before being forwarded up to higher layers (at the L2/L3
   * transition).  This is a promiscuous trace.
   *
   * \see class CallBackTraceSource
   */
  TracedCallback<Ptr<const Packet> > m_macPromiscRxTrace;

  /**
   * The trace source fired for packets successfully received by the device
   * immediately before being forwarded up to higher layers (at the L2/L3
   * transition).  This is a non- promiscuous trace.
   *
   * \see class CallBackTraceSource
   */
  TracedCallback<Ptr<const Packet> > m_macRxTrace;

  /**
   * The trace source fired when packets coming into the "top" of the device
   * are dropped at the MAC layer during reception.
   *
   * \see class CallBackTraceSource
   */
  TracedCallback<Ptr<const Packet> > m_macRxDropTrace;

  Callback<void, Ptr<Packet>, const WifiMacHeader*> m_upCallback;
  Callback<bool,uint32_t> m_queueStart;
  Callback<bool,uint32_t> m_queueStop;

  Ptr<TdmaNetDevice> m_device;
  Ptr<TdmaMacQueue> m_queue;
  int m_wifimaclow_flag;
  Ptr<TdmaMacLow> m_low;
  Ptr <MacLow> m_wifimaclow;
  TransmissionListenerUseless *m_transmissionListener;
  Ptr<SimpleWirelessChannel> m_channel;
  Ssid m_ssid;
  Ptr<Node> m_nodePtr;
  Ptr<WifiPhy> m_wifiphy;

  //  Time m_lastRxStart;
//  Time m_lastRxDuration;
//  bool m_lastRxReceivedOk;
//  Time m_lastRxEnd;
//  Time m_lastTxStart;
//  Time m_lastTxDuration;
//  EventId m_accessTimeout;
  DataRate m_bps;
  uint32_t m_slotTime;
  uint32_t m_guardTime;
  uint32_t m_tdmaInterFrameTime;
  uint32_t m_slotRemainTime;
  uint64_t m_lastpktUsedTime;

///////////////////////////////////////////////
// SATMAC
///////////////////////////////////////////////
// life time (frames) of a slot
int slot_lifetime_frame_;
// slot candidate count_3hop threshold
int c3hop_threshold_;

int delay_init_frame_num_;
int random_bch_if_single_switch_;
int choose_bch_random_switch_;

// The time duration for each slot.
double slot_time_;
/* The start time for whole TDMA scheduling. */
double start_time_;
/* Data structure for tdma scheduling. */
static int active_node_;			// How many nodes needs to be scheduled
static int *tdma_schedule_;

int slot_num_;						// The slot number it's allocated.
int slot_adj_candidate_;
int bch_slot_lock_;
static int *tdma_preamble_; 	   // The preamble data structure.
// When slot_count_ = active_nodes_, a new preamble is needed.
int slot_count_;
long long total_slot_count_;

// How many packets has been sent out?
static int tdma_ps_;
static int tdma_pr_;

//added variables
int m_frame_len;
int max_frame_len_;
int global_sti;
int global_psf;

//slot_tag **fi_list_;
Frame_info *decision_fi_;
Frame_info *collected_fi_;
Frame_info *received_fi_list_;

NodeState node_state_;
SlotState slot_state_;
int backoff_frame_num_;
int enable;
int adj_ena_;
int adj_free_threshold_;
int adj_single_slot_ena_;
int adj_frame_ena_;
int adj_frame_lower_bound_;
int adj_frame_upper_bound_;
int slot_memory_;
bool initialed_;
bool testmode_init_flag_;

Time last_log_time_;
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

std::string m_traceOutFile;
/// Provides uniform random variables.
Ptr<UniformRandomVariable> m_uniformRandomVariable;
};

} // namespace ns3


#endif /* TDMA_SATMAC_H */
