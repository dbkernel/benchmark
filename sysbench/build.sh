#!/bin/bash
#MYSQL_DIR=/home/ubuntu/mysql_20180518
MYSQL_DIR=/Users/wslu/work/mysql/mysql80-install
CUR_DIR=`pwd`

#sudo apt-get install automake gcc
cd ${CUR_DIR}/sysbench
./autogen.sh
./configure --prefix=${CUR_DIR}/sysbench_install --with-mysql=${MYSQL_DIR} --with-mysql-includes=${MYSQL_DIR}/include/ --with-mysql-libs=${MYSQL_DIR}/lib/
make
make install
cd ..
