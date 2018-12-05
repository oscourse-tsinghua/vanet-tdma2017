#ifndef SATMACPACKET_H
#define SATMACPACKET_H

#include <iostream>
#include "ns3/header.h"
#include "ns3/enum.h"
#include "ns3/ipv4-address.h"
#include <map>
#include "ns3/nstime.h"
#include "ns3/vector.h"
#include "satmac-common.h"

namespace ns3 {
namespace satmac {



enum MessageType
{
  SATMACTYPE_FI  = 1,         //!< SATMACTYPE_FI
};


class TypeHeader : public Header
{
public:
  /// c-tor
  TypeHeader (MessageType t);

  ///\name Header serialization/deserialization
  //\{
  static TypeId GetTypeId ();
  TypeId GetInstanceTypeId () const;
  uint32_t GetSerializedSize () const;
  void Serialize (Buffer::Iterator start) const;
  uint32_t Deserialize (Buffer::Iterator start);
  void Print (std::ostream &os) const;
  //\}

  /// Return type
  MessageType Get () const
  {
    return m_type;
  }
  /// Check that type if valid
  bool IsValid () const
  {
    return m_valid; //FIXME that way it wont work
  }
  bool operator== (TypeHeader const & o) const;
private:
  MessageType m_type;
  bool m_valid;
};

std::ostream & operator<< (std::ostream & os, TypeHeader const & h);

class FiHeader : public Header
{
public:
  /// c-tor
  FiHeader ();
  FiHeader (uint32_t framelength, int global_sti, slot_tag *fi_local);
  ~FiHeader() {
  	delete m_buffer;
  	m_buffer = NULL;
  }
  ///\name Header serialization/deserialization
  //\{
  static TypeId GetTypeId ();
  TypeId GetInstanceTypeId () const;
  uint32_t GetSerializedSize () const;
  void Serialize (Buffer::Iterator start) const;
  uint32_t Deserialize (Buffer::Iterator start);
  void Print (std::ostream &os) const;
  static void setvalue(unsigned char value, int bit_len, unsigned char* buffer, int &byte_pos, int &bit_pos);
  unsigned long decode_value(unsigned int &byte_pos,unsigned int &bit_pos, unsigned int length);
  void decode_slot_tag(unsigned int &byte_pos,unsigned int &bit_pos, int slot_pos, Frame_info *fi);
  uint8_t * GetBuffer() const;
  //\}

  ///\name Fields
  //\{

  //\}


  bool operator== (FiHeader const & o) const;
private:
  int m_framelength;
  int m_global_sti;
  uint8_t *m_buffer;
  int m_fi_size;

};

std::ostream & operator<< (std::ostream & os, FiHeader const &);


}
}
#endif /* SATMACPACKET_H */
