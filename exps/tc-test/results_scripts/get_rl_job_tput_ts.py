#!/usr/bin/python

import argparse
#import dpkt
import itertools
import numpy
import os
import re
import socket
import sys
import yaml

import dpkt

TIME_SCALE = 0.05

NUM_TENANTS = 5
PORT_TO_TENANT = {
    11111: 0,
}
for i in range(100):
    PORT_TO_TENANT.update({5000 + i + (100 * tenant): tenant for tenant in range(NUM_TENANTS)})
#print 'PORT_TO_TENANT:', PORT_TO_TENANT

NUM_JOBS = 3
PORT_TO_JOB = {
    5100: 0,
    5101: 1,
    5102: 2,
    5103: 0,
    5104: 0,
    5105: 0,
    5106: 0,
    5107: 0,
    5108: 0,
    5109: 0,
    5110: 1,
    5111: 2,
}

#XXX: Build our own reader because dpkt is not designed well
# This reader also returns the actual packet length and not just the capture
# length.
class PcapReader(dpkt.pcap.Reader):
    def __iter__(self):
        self._Reader__f.seek(dpkt.pcap.FileHdr.__hdr_len__)
        first_sec = -1
        while 1:
            buf = self._Reader__f.read(dpkt.pcap.PktHdr.__hdr_len__)
            if not buf: break
            hdr = self._Reader__ph(buf)
            buf = self._Reader__f.read(hdr.caplen)
            if first_sec == -1:
                first_sec = hdr.tv_sec
            yield ((hdr.tv_sec - first_sec) + (hdr.tv_usec / 1000000.0), hdr.len, buf)

def get_flowid(pkt):
    eth = dpkt.ethernet.Ethernet(pkt) 
    if eth.type != dpkt.ethernet.ETH_TYPE_IP:
       return None
    ip = eth.data
    if ip.p != dpkt.ip.IP_PROTO_TCP and ip.p != dpkt.ip.IP_PROTO_UDP: 
        return None
    tcp = ip.data

    flowid = {'sip': socket.inet_ntoa(ip.src), 'sport': tcp.sport,
              'dip': socket.inet_ntoa(ip.dst), 'dport': tcp.dport}

    return flowid

def parse_trace_job_tput(fname):
    cur_ts = 0.0
    xs = [cur_ts]
    job_bytes = {job: {cur_ts: 0} for job in range(NUM_JOBS)}
    with open(fname) as tf:
        pkt_reader = PcapReader(tf)
        pkts = pkt_reader.readpkts()
        for pkti, (ts, plen, pkt) in enumerate(pkts):
            while ts > (cur_ts + TIME_SCALE):
                cur_ts += TIME_SCALE
                xs.append(cur_ts)
                for job in range(NUM_JOBS):
                    job_bytes[job][cur_ts] = 0
            flowid = get_flowid(pkt)
            if flowid != None:
                job = -1
                if flowid['sport'] in PORT_TO_JOB:
                    job = PORT_TO_JOB[flowid['sport']]
                elif flowid['dport'] in PORT_TO_JOB:
                    job = PORT_TO_JOB[flowid['dport']]
                if job >= 0:
                    job_bytes[job][cur_ts] += plen

    lines = [] 
    for job in range(NUM_JOBS):
        job_gbpss = [job_bytes[job][x] * 8 / TIME_SCALE / 1e9 for x in xs] 
        ldata = {'lname': 'J%d' % job, 'xs': xs, 'ys': job_gbpss}
        lines.append(ldata)

    # TODO: Could do total gbps
    #tot_gbpps = [(j1_bytes[x] + j2_bytes[x]) * 8 / TIME_SCALE / 1e9 for x in xs]

    results = {'lines': lines}

    return results

def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description='Get all of the flows that '
        'are present in the PCAP trace.')
    # TODO: I could just take in a list of files instead
    parser.add_argument('--pcap', help='The files to parse.',
        required=True)
    parser.add_argument('--outf', help='The output file.')
    args = parser.parse_args()

    # Plot the files
    lines = parse_trace_job_tput(args.pcap)
    if args.outf:
        with open(args.outf, 'w') as f:
            yaml.dump(lines, f)
    else:
        print yaml.dump(lines)

if __name__ == "__main__":
    main()
