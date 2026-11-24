// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Provide common_verification's rand_id_queue API for pulp_axi's axi_test.sv

package rand_id_queue_pkg;

  // Per-ID FIFO with random ID selection by peek
  class rand_id_queue #(type data_t = logic, int unsigned ID_WIDTH = 1);

    typedef bit [ID_WIDTH-1:0] id_t;

    local data_t m_queues[id_t][$];

    int unsigned size;

    // Class specific methods

    extern function void push(id_t id, data_t data);

    // Return the oldest entry of an ID chosen at random among the IDs with entries
    extern function data_t peek();

    extern function data_t pop_id(id_t id);

    extern function void set(id_t id, data_t data);
  endclass : rand_id_queue


  function void rand_id_queue::push(id_t id, data_t data);
    m_queues[id].push_back(data);
    size++;
  endfunction : push

  function rand_id_queue::data_t rand_id_queue::peek();
    id_t ids[$];

    foreach (m_queues[id]) begin
      ids.push_back(id);
    end
    if (ids.size() == 0) begin
      $fatal(1, "rand_id_queue::peek on an empty queue");
    end
    return m_queues[ids[$urandom_range(0, ids.size() - 1)]][0];
  endfunction : peek

  function rand_id_queue::data_t rand_id_queue::pop_id(id_t id);
    data_t data;

    if (!m_queues.exists(id)) begin
      $fatal(1, "rand_id_queue::pop_id with no entry for ID 0x%0h", id);
    end
    data = m_queues[id].pop_front();
    if (m_queues[id].size() == 0) begin
      m_queues.delete(id);
    end
    size--;
    return data;
  endfunction : pop_id

  function void rand_id_queue::set(id_t id, data_t data);
    if (!m_queues.exists(id)) begin
      $fatal(1, "rand_id_queue::set with no entry for ID 0x%0h", id);
    end
    m_queues[id][0] = data;
  endfunction : set

endpackage : rand_id_queue_pkg
