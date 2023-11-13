#!/bin/bash

#################### public params ####################

USER=
PASSWD=
HOST=localhost
PORT=3306
WH=
WARM_TIME=
TIME=
SCHEMAS=1
THREAD=
CMD=all
LOGDIR=/tmp/tpcc_log
LOGFILE=$LOGDIR/tpcc_test.log
NEEDRESET=false

TPCC_DIR=$(pwd)/tpcc-mysql
STEP=
DBPREFIX=tpcc
#MYSQL_BIN=/usr/bin/mysql
MYSQL_BIN=mysql

#################### print usage ####################

function print_usage() {
    echo "Usage:"
    echo -e "\t-u|--user mysql-user\t\t\tmysql user"
    echo -e "\t-p|--password mysql-passwd\t\tmysql password"
    echo -e "\t-h|--host [mysql-host]\t\t\tmysql host, default: 127.0.0.1 or localhost"
    echo -e "\t-P|--port [mysql-port]\t\t\tmysql port, default: 3306"
    echo -e "\t-W|--warehouses number-of-warehouses\tspecify how many warehouses"
    echo -e "\t-S|--step number\t\t\tdecide how many load data threads, example: if warehouse=20 and step=5, there will be 4 threads"
    echo -e "\t-w|--warm-time number-of-seconds\ttpcc time to warm up the data"
    echo -e "\t-t|--time number-of-seconds\t\ttpcc max running time"
    echo -e "\t-s|--schemas number-of-schemas\t\tdefault:1, specify how many schemas"
    echo -e "\t-T|--thread thread-numbers\t\ttpcc thread nums"
    echo -e "\t-c|--cmd \t\t\t\tincludes: prepare | load | run | clean | all , default: all"
    echo -e "\t\t\t\t\t\t\tprepare: create databases, tables and add indexes"
    echo -e "\t\t\t\t\t\t\tload: load data"
    echo -e "\t\t\t\t\t\t\trun: run tpcc test"
    echo -e "\t\t\t\t\t\t\tclean: clean test database"
    echo -e "\t\t\t\t\t\t\tall: all of the above"
    echo -e "\t-l|--logdir [dirpath]\t\t\tlog dir"
    echo -e "\t-r|--reset\t\t\t\tneed to clear log dir"
}

#################### parse params ####################

ARGS=$(getopt -o "u:p:h:P:W:S:w:t:s:T:l:rc:" -l "user:,password:,host:,port:,warehouses:,step:,warm-time:,time:,schemas:,thread:,logdir:,reset,cmd:" -n "test.sh" -- "$@")
eval set -- "${ARGS}"

function parse_params() {
    while true; do
        case "${1}" in
        -u | --user)
            shift
            if [[ -n "${1}" ]]; then
                USER=${1}
            fi
            ;;

        -p | --password)
            shift
            if [[ -n "${1}" ]]; then
                PASSWD=${1}
            fi
            ;;

        -h | --host)
            shift
            if [[ -n "${1}" ]]; then
                HOST=${1}
            fi
            ;;

        -P | --port)
            shift
            if [[ -n "${1}" ]]; then
                PORT=${1}
            fi
            ;;

        -W | --warehouses)
            shift
            if [[ -n "${1}" ]]; then
                WH=${1}
            fi
            ;;

        -S | --step)
            shift
            if [[ -n "${1}" ]]; then
                STEP=${1}
            fi
            ;;

        -w | --warm-time)
            shift
            if [[ -n "${1}" ]]; then
                WARM_TIME=${1}
            fi
            ;;

        -t | --time)
            shift
            if [[ -n "${1}" ]]; then
                TIME=${1}
            fi
            ;;

        -s | --schemas)
            shift
            if [[ -n "${1}" ]]; then
                SCHEMAS=${1}
            fi
            ;;

        -T | --thread)
            shift
            if [[ -n "${1}" ]]; then
                THREAD=${1}
            fi
            ;;

        -l | --logdir)
            shift
            if [[ -n "${1}" ]]; then
                LOGDIR=${1}
            fi
            ;;

        -r | --reset)
            NEEDRESET=true
            ;;

        -c | --cmd)
            shift
            if [[ -n "${1}" ]]; then
                CMD=${1}
            fi
            ;;

        --)
            shift
            break
            ;;
        esac
        shift
    done
}

function check_params() {
    if [ "$USER" == "" ]; then
        echo "ERROR: -u or --user is null"
        print_usage
        exit 1
    fi
    if [ "$PASSWD" == "" ]; then
        echo "ERROR: -p or --passwd is null"
        print_usage
        exit 1
    fi
    if [ "$WH" == "" ]; then
        echo "ERROR: -W or --warehouses is null"
        print_usage
        exit 1
    fi
    if [ "$STEP" == "" ]; then
        echo "ERROR: -S or --step is null"
        print_usage
        exit 1
    fi
    if [ "${WARM_TIME}" == "" ]; then
        echo "ERROR: -w or --warm-time is null"
        print_usage
        exit 1
    fi
    if [ "$TIME" == "" ]; then
        echo "ERROR: -t or --time is null"
        print_usage
        exit 1
    fi
    if [ "$THREAD" == "" ]; then
        echo "ERROR: --thread is null"
        print_usage
        exit 1
    fi
    if [ "$CMD" == "" ]; then
        echo "ERROR: --cmd is null"
        print_usage
        exit 1
    fi
}

#################### log ####################

loglevel=0 #DEBUG:0; INFO:1; WARNING:2; ERROR:3

function log() {
    local msg
    local logtype
    logtype=$1
    msg=$2
    datetime=$(date +'%F %H:%M:%S')
    #使用内置变量$LINENO不行，不能显示调用那一行行号
    #logformat="[${logtype}]\t${datetime}\tfuncname:${FUNCNAME[@]} [line:$LINENO]\t${msg}"
    logformat="[${logtype}] ${datetime} [${FUNCNAME[@]/log/}:line:$(caller 0 | awk '{print$1}') ] ${msg}"
    #funname格式为log ERROR main,如何取中间的ERROR字段，去掉log好办，再去掉main,用echo awk? ${FUNCNAME[0]}不能满足多层函数嵌套
    {
        case $logtype in
        DEBUG)
            [[ $loglevel -le 0 ]] && echo -e "\033[30m${logformat}\033[0m"
            ;;
        INFO)
            [[ $loglevel -le 1 ]] && echo -e "\033[32m${logformat}\033[0m"
            ;;
        WARNING)
            [[ $loglevel -le 2 ]] && echo -e "\033[33m${logformat}\033[0m"
            ;;
        ERROR)
            [[ $loglevel -le 3 ]] && echo -e "\033[31m${logformat}\033[0m"
            ;;
        esac
    } | tee -a $LOGFILE
}

#################### tpcc cmd ####################

function prepare() {
    log INFO "=========== prepare begin ============"

    for ((i = 0; i < $SCHEMAS; i++)); do
        dbname=${DBPREFIX}${WH}_s$i

        log INFO "${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -e\"drop database if exists $dbname\""
        ${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -e"drop database if exists $dbname" | tee -a $LOGFILE

        log INFO "${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -e\"create database $dbname\""
        ${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -e"create database $dbname" | tee -a $LOGFILE

        log INFO "${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -D$dbname < ${TPCC_DIR}/create_table.sql"
        ${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -D$dbname <${TPCC_DIR}/create_table.sql | tee -a $LOGFILE

        log INFO "${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -D$dbname < ${TPCC_DIR}/add_fkey_idx.sql"
        ${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -D$dbname <${TPCC_DIR}/add_fkey_idx.sql | tee -a $LOGFILE
    done

    log INFO "=========== prepare end ============"
}

function load_multi() {
    log INFO "=========== load_multi begin ============"

    for ((schema = 0; schema < $SCHEMAS; schema++)); do
        dbfullname=${DBPREFIX}${WH}_s${schema}

        log INFO "$TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 1 -m 1 -n $WH >>$LOGDIR/tpcc_load_${dbfullname}_0.log 2>&1 &"
        $TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 1 -m 1 -n $WH >>$LOGDIR/tpcc_load_${dbfullname}_0.log 2>&1 &
        x=1
        while [ $x -le $WH ]; do
            echo $x $(($x + $STEP - 1)) | tee -a $LOGFILE

            log INFO "$TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 2 -m $x -n $(($x + $STEP - 1)) >>$LOGDIR/tpcc_load_${dbfullname}_1.log 2>&1 &"
            $TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 2 -m $x -n $(($x + $STEP - 1)) >>$LOGDIR/tpcc_load_${dbfullname}_1.log 2>&1 &

            log INFO "$TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 3 -m $x -n $(($x + $STEP - 1)) >>$LOGDIR/tpcc_load_${dbfullname}_2.log 2>&1 &"
            $TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 3 -m $x -n $(($x + $STEP - 1)) >>$LOGDIR/tpcc_load_${dbfullname}_2.log 2>&1 &

            log INFO "$TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 4 -m $x -n $(($x + $STEP - 1)) >>$LOGDIR/tpcc_load_${dbfullname}_3.log 2>&1 &"
            $TPCC_DIR/tpcc_load -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -l 4 -m $x -n $(($x + $STEP - 1)) >>$LOGDIR/tpcc_load_${dbfullname}_3.log 2>&1 &

            x=$(($x + $STEP))
        done

        for job in $(jobs -p); do
            echo $job | tee -a $LOGFILE
            wait $job
        done
    done

    log INFO "=========== load_multi end ============"
}

function run() {
    log INFO "=========== run begin ============"

    for ((i = 0; i < $SCHEMAS; i++)); do
        dbfullname=${DBPREFIX}${WH}_s$i
        log INFO "$TPCC_DIR/tpcc_start -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -c $THREAD -r $WARM_TIME -l $TIME >>$LOGDIR/tpcc_start_${dbfullname}.log 2>&1 &"
        $TPCC_DIR/tpcc_start -h $HOST -d $dbfullname -u $USER -p $PASSWD -w $WH -c $THREAD -r $WARM_TIME -l $TIME >>$LOGDIR/tpcc_start_${dbfullname}.log 2>&1 &
    done

    log INFO "=========== run end ============"
}

function cleanup() {
    log INFO "=========== cleanup begin ============"

    for ((i = 0; i < $SCHEMAS; i++)); do
        dbname=${DBPREFIX}${WH}_s$i

        log INFO "${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -e\"drop database if exists $dbname\""
        ${MYSQL_BIN} -u$USER -p$PASSWD -h$HOST -e"drop database if exists $dbname" | tee -a $LOGFILE
    done

    log INFO "=========== cleanup end ============"
}

#################### main ####################

if [ $# == 1 ]; then
    print_usage
    exit 1
fi

parse_params $@
check_params

if [ ! -d $LOGDIR ]; then
    mkdir $LOGDIR
fi

if [ "$NEEDRESET" = true ]; then
    log INFO "clear log dir $LOGDIR"
    rm -rf $LOGDIR/*
fi

LOGFILE=$LOGDIR/tpcc_test.log
log INFO "user=$USER, passwd=$PASSWD, host=$HOST, port=$PORT, warehouses=$WH, step=$STEP, warm-time=${WARM_TIME}, time=$TIME, schemas=$SCHEMAS, threads=$THREAD, logdir=$LOGDIR, needresetlog=$NEEDRESET, cmd=$CMD"

if [ $CMD == "prepare" ] || [ $CMD == "all" ]; then
    prepare
fi

if [ $CMD == "load" ] || [ $CMD == "all" ]; then
    load_multi
fi

if [ $CMD == "run" ] || [ $CMD == "all" ]; then
    run
fi

if [ $CMD == "cleanup" ] || [ $CMD == "all" ]; then
    cleanup
fi
