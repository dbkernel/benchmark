#!/bin/bash

###################################################################
mysql_host='10.255.0.55'
mysql_db='sbtest'
mysql_port=8309
#mysql_port=3306
mysql_user='admin'
mysql_password='admin'
mysql_table_size=10000000
mysql_tables=10
skip_trx=on
sleep_time=60
run_time=300
tp_thds=(16 32 64 128 256 512)
fileio_thds=(1 4 8 16 32)

###################################################################
sysbench=$(which sysbench)
#lua=/usr/local/share/sysbench
lua=/usr/share/sysbench # for centos
mysql_read_wirte=$lua/oltp_read_write.lua
mysql_insert=$lua/oltp_insert.lua
mysql_read_only=$lua/oltp_read_only.lua
mysql_write_only=$lua/oltp_write_only.lua
mysql_select_point=$lua/select_random_points.lua
mysql_update_index=$lua/oltp_update_index.lua

####################################################################

prepare() {
        $sysbench \
                $mysql_read_wirte \
                --db-driver=mysql \
                --mysql-host=$mysql_host \
                --mysql-db=$mysql_db \
                --mysql-port=$mysql_port \
                --mysql-user=$mysql_user \
                --mysql-password=$mysql_password \
                --table-size=$mysql_table_size \
                --tables=$mysql_tables \
                --time=1000000000 \
                --report-interval=10 \
                --rand-type=uniform \
                --create_secondary=on \
                --threads=64 \
                prepare
}

cleanup() {
        $sysbench \
                $mysql_read_wirte \
                --db-driver=mysql \
                --mysql-host=$mysql_host \
                --mysql-db=$mysql_db \
                --mysql-port=$mysql_port \
                --mysql-user=$mysql_user \
                --mysql-password=$mysql_password \
                --table-size=$mysql_table_size \
                --tables=$mysql_tables \
                --time=$run_time \
                --report-interval=10 \
                --rand-type=uniform \
                --create_secondary=off \
                --num-threads=200 \
                --create_single_int_hash=1 \
                --create_single_char_hash=0 \
                --create_single_char_hash=0 \
                --create_single_datetime=0 \
                --create_range_datetime=0 \
                cleanup
}

oltp_insert() {
        $sysbench \
                $mysql_insert \
                --db-driver=mysql \
                --mysql-host=$mysql_host \
                --mysql-db=$mysql_db \
                --mysql-port=$mysql_port \
                --mysql-user=$mysql_user \
                --mysql-password=$mysql_password \
                --table-size=$mysql_table_size \
                --tables=$mysql_tables \
                --time=$run_time \
                --report-interval=10 \
                --rand-type=uniform \
                --auto_inc=off \
                --create_secondary=off \
                --num-threads=20 \
                --create_single_int_hash=1 \
                --create_single_char_hash=0 \
                --create_single_char_hash=0 \
                --create_single_datetime=0 \
                --create_range_datetime=0 \
                run
}

ro() {
        for each in ${tp_thds[@]}; do
                $sysbench \
                        $mysql_read_only \
                        --db-driver=mysql \
                        --mysql-host=$mysql_host \
                        --mysql-db=$mysql_db \
                        --mysql-port=$mysql_port \
                        --mysql-user=$mysql_user \
                        --mysql-password=$mysql_password \
                        --table-size=$mysql_table_size \
                        --tables=$mysql_tables \
                        --time=$run_time \
                        --report-interval=1 \
                        --num-threads=$each \
                        --skip_trx=${skip_trx} \
                        run >sysbench_${each}.log

                sleep ${sleep_time}

        done
}

# This script will run 6 tests, each lasting 4 minutes.
# It will run 1 through 64 threaded tests, which seem to be the most common tests to run.
# This test does selects, updates, and various other things and is considered
# to be a "read / write" MySQL mixed workload.
rw() {
        for each in ${tp_thds[@]}; do
                #        for each in 128; do
                $sysbench \
                        $mysql_read_wirte \
                        --db-driver=mysql \
                        --mysql-host=$mysql_host \
                        --mysql-db=$mysql_db \
                        --mysql-port=$mysql_port \
                        --mysql-user=$mysql_user \
                        --mysql-password=$mysql_password \
                        --table-size=$mysql_table_size \
                        --tables=$mysql_tables \
                        --time=$run_time \
                        --report-interval=1 \
                        --num-threads=$each \
                        run >sysbench_${each}.log

                sleep ${sleep_time}
        done
}

wo() {
        for each in ${tp_thds[@]}; do
                $sysbench \
                        $mysql_write_only \
                        --db-driver=mysql \
                        --mysql-host=$mysql_host \
                        --mysql-db=$mysql_db \
                        --mysql-port=$mysql_port \
                        --mysql-user=$mysql_user \
                        --mysql-password=$mysql_password \
                        --table-size=$mysql_table_size \
                        --tables=$mysql_tables \
                        --time=$run_time \
                        --report-interval=1 \
                        --num-threads=$each \
                        run >sysbench_${each}.log

                sleep ${sleep_time}

        done
}

sp() {
        for each in ${tp_thds[@]}; do
                $sysbench \
                        $mysql_select_point \
                        --db-driver=mysql \
                        --mysql-host=$mysql_host \
                        --mysql-db=$mysql_db \
                        --mysql-port=$mysql_port \
                        --mysql-user=$mysql_user \
                        --mysql-password=$mysql_password \
                        --table-size=$mysql_table_size \
                        --tables=$mysql_tables \
                        --time=$run_time \
                        --report-interval=1 \
                        --num-threads=$each \
                        run >sysbench_${each}.log

                sleep ${sleep_time}

        done
}

ui() {
        for each in ${tp_thds[@]}; do
                $sysbench \
                        $mysql_update_index \
                        --db-driver=mysql \
                        --mysql-host=$mysql_host \
                        --mysql-db=$mysql_db \
                        --mysql-port=$mysql_port \
                        --mysql-user=$mysql_user \
                        --mysql-password=$mysql_password \
                        --table-size=$mysql_table_size \
                        --tables=$mysql_tables \
                        --time=$run_time \
                        --report-interval=1 \
                        --num-threads=$each \
                        run >sysbench_${each}.log

                sleep ${sleep_time}

        done
}

fileio() {
        # ../sandbox1.sh -fileio prepare 4
        if [ $1 == "prepare" ]; then
                num=$2
                filesize=$num'G'
                filenum=$((num * 16))
                $sysbench --test=fileio --file-total-size=$filesize --file-num=$filenum prepare
        else
                for run in 1 2 3; do
                        for thread in $fileio_thds; do
                                echo "Performing test RW-${thread}T-${run}"
                                $sysbench \
                                        --test=fileio \
                                        --file-total-size=4G \
                                        --file-test-mode=rndwr \
                                        --max-time=60 \
                                        --max-requests=0 \
                                        --file-block-size=4K \
                                        --file-num=64 \
                                        --num-threads=${thread} \
                                        run >/home/e3mark/Projects/benchpress/logs/RW-${thread}T-${run}

                                echo "Performing test RR-${thread}T-${run}"
                                $sysbench \
                                        --test=fileio \
                                        --file-total-size=4G \
                                        --file-test-mode=rndrd \
                                        --max-time=60 \
                                        --max-requests=0 \
                                        --file-block-size=4K \
                                        --file-num=64 \
                                        --num-threads=${thread} \
                                        run >/home/e3mark/Projects/benchpress/logs/RR-${thread}T-${run}
                        done
                done
        fi
}

cpu() {
        $sysbench --test=cpu --cpu-max-prime=20000 run
}

# Todo: check installed sysbench version if >= 0.5.*
echo "Positional Parameters"
echo "$0 -prepare/-cleanup/-rw"
echo '$0 = ' $0
echo '$1 = ' $1
echo '$2 = ' $2
echo '$3 = ' $3

case $1 in
'-fileio')
        fileio $2 $3
        ;;
'-prepare')
        prepare
        ;;
'-cleanup')
        cleanup
        ;;
'-insert')
        oltp_insert
        ;;
'-ro')
        ro
        ;;
'-rw')
        rw
        ;;
'-ro')
        ro
        ;;
'-wo')
        wo
        ;;
'-sp')
        sp
        ;;
'-ui')
        ui
        ;;
*) ;;
esac

# usage
# xxx.sh -prepare
# xxx.sh -rw # oltp_read_write
# xxx.sh -ro # oltp_read_only
# ....
# xxx.sh -cleanup
