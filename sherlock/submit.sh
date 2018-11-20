#!/bin/bash
# Works with interact and predict.

display_usage() { 
    printf "Usage: $0 
    [-h] [-c NUM_CPUS] [-g NUM_GPUS] [-d DEPENDENCY] [-m MEMORY] [-t TIME] [-l] [--local]
    JOB_NAME OUTPUT_DIR COMMAND [-- COMMAND_FLAGS]\n" 
    } 

function join_by { local IFS="$1"; shift; echo "$*"; }


# Adapted from
# http://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
 
NUM_GPUS=0
NUM_CPUS=1
MEMORY=""
TIME=""
LOG=0
LOCAL=0

SHORT=hc:g:d:m:t:la
LONG=help,num_cpus:,num_gpus:,dependency:,memory:,time:,log,local

# -temporarily store output to be able to check for errors
# -activate advanced mode getopt quoting e.g. via “--options”
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# use eval with "$PARSED" to properly handle the quoting
eval set -- "$PARSED"

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -l|--log)
            LOG=1
            shift
            ;;
        -a|--local)
            LOCAL=1
            shift
            ;;
        -h|--help)
            display_usage
            exit
            ;;
        -d|--dependency)
            DEPENDENCY="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -g|--num_gpus)
            NUM_GPUS="$2"
            shift 2
            ;;
        -c|--num_cpus)
            NUM_CPUS="$2"
            shift 2
            ;;
        -t|--time)
            TIME="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

# handle non-option arguments
if [[ $# -le 3 ]]; then
    echo "$0: Need to provide positional arguments"
    display_usage
    exit 4
fi
JOB_NAME=$1
shift
OUTPUT_DIR=$1
shift
COMMAND=$@

SBATCH_FLAGS=()
SBATCH_FLAGS+=("--partition=rondror")
SBATCH_FLAGS+=("--mail-type=FAIL")

SBATCH_FLAGS+=("--job-name="$JOB_NAME"")
SBATCH_FLAGS+=("--output=$OUTPUT_DIR/${JOB_NAME}.out")
SBATCH_FLAGS+=("--error=$OUTPUT_DIR/${JOB_NAME}.err")
mkdir -p $OUTPUT_DIR

SBATCH_FLAGS+=("--dependency=$DEPENDENCY")

if (( NUM_GPUS == 1 ))
then
    NUM_CPUS=2
elif (( NUM_GPUS == 2))
then
    NUM_CPUS=4
elif (( NUM_GPUS == 4))
then
    NUM_CPUS=8
elif (( NUM_GPUS == 8))
then
    NUM_CPUS=16
fi

if [ "$NUM_GPUS" -ne 0 ]
then
    if [ "$NUM_GPUS" -eq 8 ]
    then
        SBATCH_FLAGS+=("--ntasks-per-node=1")
    else
        SBATCH_FLAGS+=("--ntasks-per-socket=1")
    fi
    SBATCH_FLAGS+=("--gres-flags=enforce-binding")
    SBATCH_FLAGS+=("--gres=gpu:$NUM_GPUS")
    SBATCH_FLAGS+=("--constraint=GPU_MEM:12GB")
fi
SBATCH_FLAGS+=("--cpus-per-task=$NUM_CPUS")

if [ -n "$MEMORY" ]
then
    SBATCH_FLAGS+=("--mem=$MEMORY")
fi

if [ -n "$TIME" ]
then
    SBATCH_FLAGS+=("--time=$TIME")
fi

if [ "$LOG" -ne "0" ]
then
    COMMAND="$COMMAND -l $OUTPUT_DIR/${JOB_NAME}.log"
fi


SBATCH_FLAGS=$(printf "#SBATCH %s\n" "${SBATCH_FLAGS[@]}")
MODULE_LOADS=$(printf "source ~/.ppi")
SBATCH_SCRIPT=$(printf "#!/bin/bash\n%s\n%s\n%s%s" "$SBATCH_FLAGS" "$MODULE_LOADS" "$COMMAND")
SBATCH_NAME=$OUTPUT_DIR/${JOB_NAME}.sbatch

if [ "$LOCAL" -ne "0" ]
then
    eval $COMMAND >$OUTPUT_DIR/${JOB_NAME}.out 2>$OUTPUT_DIR/${JOB_NAME}.err
    result=$?
    echo "1"
    exit $result
else
    printf "$SBATCH_SCRIPT\n" > $SBATCH_NAME
    RES=$(sbatch $SBATCH_NAME)
    ID=${RES##* }
    echo $ID
fi
