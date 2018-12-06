#include "mbr-header.h"

#include "ns3/address-utils.h"
#include "ns3/packet.h"

using namespace ns3;
using namespace mbr;

//-----------------------------------------------------------------------------
// RREP
//-----------------------------------------------------------------------------
MbrHeader::MbrHeader (uint8_t prefixSize, uint8_t hopCount, Ipv4Address dst,
                        uint32_t dstSeqNo, Ipv4Address origin, Time lifeTime,
						uint64_t geohash, uint8_t *mac, uint16_t direction,
						float latitude, float longitude) :
  m_flags (0), m_prefixSize (prefixSize), m_hopCount (hopCount),
  m_dst (dst), m_dstSeqNo (dstSeqNo), m_origin (origin),
  m_geohash (geohash), m_direction(direction),
  m_latitude(latitude), m_longitude(longitude)
{
  m_lifeTime = uint32_t (lifeTime.GetMilliSeconds ());
  if(mac != NULL)
	  memcpy(m_mac, mac, 6 );
//  else
//
}

NS_OBJECT_ENSURE_REGISTERED (MbrHeader);

TypeId
MbrHeader::GetTypeId ()
{
  static TypeId tid = TypeId ("ns3::mbr::MbrHeader")
    .SetParent<Header> ()
    .SetGroupName("Mbr")
    .AddConstructor<MbrHeader> ()
  ;
  return tid;
}

TypeId
MbrHeader::GetInstanceTypeId () const
{
  return GetTypeId ();
}

uint32_t
MbrHeader::GetSerializedSize () const
{
  return 41;//19;
}

/**
* \ingroup mbr
* \brief MBR hello packet header
  \verbatim
  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     Type      |R|A|    Reserved     |Prefix Sz|   Hop Count   |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                     Destination IP address                    |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                  Destination Sequence Number                  |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                    Originator IP address                      |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                           Lifetime                            |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                                                        		  |
  +							geohash								  +
  |                                                               |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     mac0      |     mac1      |     mac2      |     mac3      |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     mac4      |     mac5      |     	direction      		  |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                           latitude                            |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                           longitude                           |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  \endverbatim
*/
void
MbrHeader::Serialize (Buffer::Iterator i) const
{
	int j;
	uint32_t t1,t2;
  i.WriteU8 (m_flags);
  i.WriteU8 (m_prefixSize);
  i.WriteU8 (m_hopCount);
  WriteTo (i, m_dst);
  i.WriteHtonU32 (m_dstSeqNo);
  WriteTo (i, m_origin);
  i.WriteHtonU32 (m_lifeTime);
  i.WriteHtonU64(m_geohash);
  for(j=0; j<6; j++)
	  i.WriteU8(m_mac[j]);
  memcpy(&t1, &m_latitude, 4);
  memcpy(&t2, &m_longitude, 4);
  i.WriteHtonU32(t1);
  i.WriteHtonU32(t2);

}

uint32_t
MbrHeader::Deserialize (Buffer::Iterator start)
{
  Buffer::Iterator i = start;
  int j;
  uint32_t t1,t2;
  m_flags = i.ReadU8 ();
  m_prefixSize = i.ReadU8 ();
  m_hopCount = i.ReadU8 ();
  ReadFrom (i, m_dst);
  m_dstSeqNo = i.ReadNtohU32 ();
  ReadFrom (i, m_origin);
  m_lifeTime = i.ReadNtohU32 ();
  m_geohash = i.ReadNtohU64 ();
  for(j=0; j<6; j++)
	  m_mac[j] = i.ReadU8();
  t1 = i.ReadNtohU32 ();
  t2 = i.ReadNtohU32 ();
  memcpy(&m_latitude, &t1, 4);
  memcpy(&m_longitude, &t2, 4);

  uint32_t dist = i.GetDistanceFrom (start);
  NS_ASSERT (dist == GetSerializedSize ());
  return dist;
}

void
MbrHeader::Print (std::ostream &os) const
{
  os << "destination: ipv4 " << m_dst << " sequence number " << m_dstSeqNo;
  if (m_prefixSize != 0)
    {
      os << " prefix size " << m_prefixSize;
    }
  os << " source ipv4 " << m_origin << " lifetime " << m_lifeTime
     << " acknowledgment required flag " << (*this).GetAckRequired ();
}

void
MbrHeader::SetLifeTime (Time t)
{
  m_lifeTime = t.GetMilliSeconds ();
}

Time
MbrHeader::GetLifeTime () const
{
  Time t (MilliSeconds (m_lifeTime));
  return t;
}

void
MbrHeader::SetAckRequired (bool f)
{
  if (f)
    m_flags |= (1 << 6);
  else
    m_flags &= ~(1 << 6);
}

bool
MbrHeader::GetAckRequired () const
{
  return (m_flags & (1 << 6));
}

void
MbrHeader::SetPrefixSize (uint8_t sz)
{
  m_prefixSize = sz;
}

uint8_t
MbrHeader::GetPrefixSize () const
{
  return m_prefixSize;
}

bool
MbrHeader::operator== (MbrHeader const & o) const
{
  return (m_flags == o.m_flags && m_prefixSize == o.m_prefixSize &&
          m_hopCount == o.m_hopCount && m_dst == o.m_dst && m_dstSeqNo == o.m_dstSeqNo &&
          m_origin == o.m_origin && m_lifeTime == o.m_lifeTime);
}

void
MbrHeader::SetHello (Ipv4Address origin, uint32_t srcSeqNo, Time lifetime)
{
  m_flags = 0;
  m_prefixSize = 0;
  m_hopCount = 0;
  m_dst = origin;
  m_dstSeqNo = srcSeqNo;
  m_origin = origin;
  m_lifeTime = lifetime.GetMilliSeconds ();
}

std::ostream &
operator<< (std::ostream & os, MbrHeader const & h)
{
  h.Print (os);
  return os;
}
