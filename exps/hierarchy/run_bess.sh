#!/bin/bash

RUN_START=0
RUN_END=40


for i in $(seq $RUN_START $RUN_END)
do
#    for qtype in bess
#    do
#        # Configure the network on all of the servers
#        sudo -u ubuntu -H ./config_all_bess_netconf.sh $qtype.conf
#
#        # Note: tcpdump has already been started as part of configuring BESS (fairnes.bess)
#        #  However, in order to get this to work, bessctl is run in the background
#        #  an may not be finished running yet.
#        # For now, just sleep and hope BESS gets configured correctly.
#        sleep 2
#        ping 10.10.102.1 -c 1
#        if [ $? -ne 0 ]
#        then
#            echo "BESS failed to configure correctly!"
#            #exit 1
#            continue
#        fi
#
#        # Should be RX size of packet capture.
#        sudo rm -f /dev/shm/hier_tcp_flows.pcap /dev/shm/hier_tcp_flows_loom1.pcap /dev/shm/hier_tcp_flows_loom2.pcap 
#        sudo tcpdump -i loom1 -w /dev/shm/hier_tcp_flows_loom1.pcap -s 64 src 10.10.1.1 or src 10.10.101.1 or src 10.10.102.1 &
#        sudo tcpdump -i loom2 -w /dev/shm/hier_tcp_flows_loom2.pcap -s 64 src 10.10.1.1 or src 10.10.101.1 or src 10.10.102.1 &
#        #TODO: I could collect a trace from BESS internals as well
#
#        JOBS=()
#        time sudo -u ubuntu -H ./spark_terasort_h1.sh &> tmp_sort1.out &
#        JOBS+=$!
#        time sudo -u ubuntu2 -H ./spark_terasort_h2.sh &> tmp_sort2.out &
#        JOBS+=" $!"
#        ./run_memcached_ycsb.py --expname $qtype.2spark.$i --high-prio
#        wait ${JOBS[@]}
#
#        sudo killall tcpdump
#        mergecap -F pcap -w /dev/shm/hier_tcp_flows.pcap /dev/shm/hier_tcp_flows_loom1.pcap /dev/shm/hier_tcp_flows_loom2.pcap 
#        ./results_scripts/get_tenant_tput_ts.py --pcap /dev/shm/hier_tcp_flows.pcap --outf results/tputs.$qtype.$i.yaml
#
#        rm tmp_sort1.out
#        rm tmp_sort2.out
#        cp /dev/shm/hier_tcp_flows.pcap results/hier_tcp_flows.$qtype.pcap
#        sudo rm -f /dev/shm/hier_tcp_flows.pcap
#    done

    #for qtype in bess-sq bess-mq bess bess-qpf
    for qtype in bess-qpf
    do
        # Configure the network on all of the servers
        sudo -u ubuntu -H ./config_all_bess_netconf.sh $qtype.conf

        # Note: tcpdump has already been started as part of configuring BESS (fairnes.bess)
        #  However, in order to get this to work, bessctl is run in the background
        #  an may not be finished running yet.
        # For now, just sleep and hope BESS gets configured correctly.
        sleep 2
        ping 10.10.102.1 -c 1
        if [ $? -ne 0 ]
        then
            echo "BESS failed to configure correctly!"
            #exit 1
            continue
        fi

        sudo tcpdump -i loom1 -w /dev/shm/hier_tcp_flows.pcap -s 64 src 10.10.1.1 or src 10.10.101.1 or src 10.10.102.1 &
        #TODO: I could collect a trace from BESS internals as well

        JOBS=()
        time sudo -u ubuntu -H ./spark_terasort_h1.sh &> tmp_sort1.out &
        JOBS+=$!
        time sudo -u ubuntu2 -H ./spark_terasort_h2.sh &> tmp_sort2.out &
        JOBS+=" $!"
        ./run_memcached_ycsb.py --expname $qtype.2spark.$i --high-prio
        wait ${JOBS[@]}

        cat tmp_sort1.out > results/two_sort.$qtype.$i.out
        echo "" >> results/two_sort.$qtype.$i.out;
        echo "" >> results/two_sort.$qtype.$i.out;
        cat tmp_sort2.out >> results/two_sort.$qtype.$i.out


        sudo killall tcpdump
        ./results_scripts/get_tenant_tput_ts.py --pcap /dev/shm/hier_tcp_flows.pcap --outf results/tputs.$qtype.$i.yaml

        rm tmp_sort1.out
        rm tmp_sort2.out
        #cp /dev/shm/hier_tcp_flows.pcap results/hier_tcp_flows.$qtype.pcap
        sudo rm -f /dev/shm/hier_tcp_flows.pcap
    done
done
