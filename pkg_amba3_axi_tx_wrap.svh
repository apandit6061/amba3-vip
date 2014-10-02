/*==============================================================================

The MIT License (MIT)

Copyright (c) 2014 Luuvish Hwang

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

================================================================================

    File         : pkg_amba3_axi_tx_wrap.svh
    Author(s)    : luuvish (github.com/luuvish/amba3-vip)
    Modifier     : luuvish (luuvish@gmail.com)
    Descriptions : package for amba 3 axi wrap transaction

==============================================================================*/

class amba3_axi_tx_wrap_t
#(
  parameter integer TXID_SIZE = 4,
                    ADDR_SIZE = 32,
                    DATA_SIZE = 32,
                    BEAT_SIZE = 32
)
extends amba3_axi_tx_t #(TXID_SIZE, ADDR_SIZE, DATA_SIZE);

  localparam integer STRB_SIZE = DATA_SIZE / 8;
  localparam integer ADDR_BASE = $clog2(DATA_SIZE / 8);
  localparam integer BEAT_BASE = $clog2(BEAT_SIZE / 8);

  typedef logic [ADDR_SIZE - 1:0] addr_t;
  typedef logic [DATA_SIZE - 1:0] data_t;
  typedef logic [STRB_SIZE - 1:0] strb_t;
  typedef logic [BEAT_SIZE - 1:0] beat_t;

  constraint mode_c {
    addr.addr[BEAT_BASE - 1:0] == '0;
    addr.len inside {1, 3, 7, 15};
    addr.burst == WRAP;
  }

  function new (mode_t mode, addr_t addr, beat_t beat [] = {}, int size = 0);
    assert((mode == READ ? size : beat.size) inside {2, 4, 8, 16});
    assert(addr[BEAT_BASE - 1:0] == '0);

    this.mode = mode;
    this.txid = $urandom_range(0, (1 << TXID_SIZE) - 1);

    this.addr = '{
      addr : addr,
      len  : (mode == READ ? size : beat.size) - 1,
      size : $clog2(DATA_SIZE / 8),
      burst: WRAP,
      lock : NORMAL,
      cache: cache_attr_t'('0),
      prot : NON_SECURE
    };

    write(beat);

    this.resp = OKAY;
  endfunction

  function void write (beat_t beat []);
    foreach (beat [i]) begin
      int upper, lower;
      addr_t addr = get_addr(i, upper, lower);

      this.data[i] = '{
        data: set_data(beat[i], (upper + 1) * 8, lower * 8),
        strb: set_strb('1, upper + 1, lower),
        resp: OKAY,
        last: (i == this.addr.len)
      };
    end
  endfunction

  function void read (beat_t beat []);
    for (int i = 0; i < this.addr.len + 1; i++) begin
      int upper, lower;
      addr_t addr = get_addr(i, upper, lower);

      beat[i] = get_data(this.data[i].data, (upper + 1) * 8, lower * 8);
    end
  endfunction

  function addr_t get_addr (int i, output int upper, output int lower);
    const int number_bytes = BEAT_SIZE / 8;
    int       burst_length = this.addr.len + 1;
    addr_t wrap_boundary = (this.addr.addr >> (number_bytes * burst_length))
                         << (number_bytes * burst_length);

    addr_t address_n;
    int lower_byte_lane;
    int upper_byte_lane;

    address_n = this.addr.addr;
    if (i != 0)
      address_n = (address_n >> BEAT_BASE) << BEAT_BASE;
    address_n += i * number_bytes;
    if (address_n >= wrap_boundary + number_bytes * burst_length)
      address_n -= number_bytes * burst_length;

    lower_byte_lane = address_n[ADDR_BASE - 1:0];

    upper_byte_lane = lower_byte_lane;
    if (i == 0)
      upper_byte_lane = (upper_byte_lane >> BEAT_BASE) << BEAT_BASE;
    upper_byte_lane += (number_bytes - 1);

    upper = upper_byte_lane;
    lower = lower_byte_lane;
    return address_n;
  endfunction

  function data_t set_data (beat_t beat, int upper, int lower);
    return (beat << lower);
  endfunction

  function strb_t set_strb (strb_t strb, int upper, int lower);
    return ((strb >> lower) & ((1 << (upper - lower)) - 1)) << lower;
  endfunction

  function beat_t get_data (data_t data, int upper, int lower);
    return ((data >> lower) & ((1 << (upper - lower)) - 1));
  endfunction

endclass
