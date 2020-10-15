#!/bin/bash
# upload script for uploading CJ packages to
# CJHub








#####################################
# get status that location url exists
get_status(){
  ###########

local SESSION_URI=$1
local FILENAME=$2

local FILESIZE=$(wc -c $FILENAME | awk '{print $1}')

# make an empty query
local code=$(curl -v -w "%{http_code}" -X PUT -H 'content-length: 0' -H 'content-type: application/json' -H 'content-range: bytes */*' -d '' -o /dev/null $SESSION_URI) 

local __code=$3
eval $__code=$code
# you can give an input for range of upload as well
if [ $# -eq 4 ] ; then
  # calculate range
  local uploaded_range=$(get_upload_range_header $SESSION_URI)
  # no Range param is returned. Either small file/200 OK or else something bad happened
  if [[ ! $? -eq 0 ]] ; then
    [[ ! $code -eq 200 ]] && uploaded_range="bytes=0-0";
  fi
  
  local __range=$4
  eval $__range=$uploaded_range
fi
}

##########################
get_upload_range_header(){
  ########################
local SESSION_URI=$1

local HEADERS=$(curl -v -X PUT -H 'content-length: 0' -H 'content-type: application/json' -H 'content-range: bytes */*' -d '' $SESSION_URI 2>&1 | grep '<' | sed 's/< //')
local IFS=$'\n'      # Change IFS to new line
local HEADERS=($HEADERS) # split to array $names

for (( i=0; i<${#HEADERS[@]}; i++ ))
do
    local THIS_HEADER=${HEADERS[$i]}
    local KEY=$( echo ${THIS_HEADER%%[[:space:]]*} | sed 's/://') 
    local VALUE=$( echo ${THIS_HEADER##$KEY}  | sed 's/://;s/^[[:space:]]//')
    if [[ "$KEY" == 'Range' ]]; then echo "$VALUE" ; exit 0; fi
done

exit 1;
}


##############
upload_file(){
  ############

#upload a given file

local SESSION_URI=$1
local FILE=$2
local RANGE=$3

 # build the file
echo "range: $RANGE"
 # upload
  curl -sv -X PUT --upload-file $FILE $SESSION_URI >$UPLOAD_LOG_FILE 2>&1
  
  if [[ $? -ne 0 ]] ; then
    # detected error
    cat $UPLOAD_LOG_FILE
    echo "     CJHub: $FILE : ERROR" 
    exit 1;
  fi

}


#######################
create_session_uri() {
  #####################

  
# variables that go into the cloud function
# getSignedResUrl to get a location url
# ex. 
#   get_sessions_url CJID PID FILENAME 
#   sessions_url=$(get_sessions_url moosh somedir test.tar)
#echo $sessions_url


local CJID=$1
local PID=$2
local FILENAME=$3
# execute a function call for resumable url
# FIXME: This must require CJKey, otherwise, anyone can get an upload url
local SESSION_URI=$(curl -X POST -H 'Content-Type: application/json' -d '{"pid":"'$PID'","cj_id":"'$CJID'","filename":"'"$FILENAME"'"}' 'https://us-central1-testcj-12345.cloudfunctions.net/getSignedResUrl' 2>$UPLOAD_LOG_FILE) 

if [[ ! -z $SESSION_URI ]]; then
        echo $SESSION_URI > $(get_cjhubURI_name "$CJID" "$PID" "$FILENAME")
else
      cat $UPLOAD_LOG_FILE
      cjhub_message "Failed to create upload location url for $PID/$FILENAME" 
      exit 1;
fi

}

###############
rm_extension(){
  #############
local fullfile=$1
local filename=$(basename -- "$fullfile")
local dirname=$(dirname "$fullfile")
#local extension="${filename##*.}"
filename="${filename%.*}"
echo $filename
}



####################
get_cjhubURI_name(){
  ##################

local CJID=$1
local pid=$2
local filename=$3
filename=${filename//\//\_} # replace / with _
echo ".cjhubURI_"$CJID"_"$pid"_"$(rm_extension "$filename")
}


###########################
get_upload_log_filename() {
  #########################
local CJID=$1
local pid=$2
local filename=$3 
filename=${filename//\//\_} # replace / with _
  echo ".upload_log_"$CJID"_"$pid"_"$(rm_extension "$filename")".txt"
}

################
cjhub_message(){
  ##############
echo "          CJhub: $@"
}





















#####################################################
CJID="moosh"
pid="0854a767f859fda5b879edc8f49634f1cf58bfba"
#filename="1/logs/CJ_0854a767f859fda5b879edc8f49634f1cf58bfba_1_rethink_generalization_monajemi.stderr"
filename="1/checkpoint.pth.tar"

# exec upload
CJHUB_URI_FILE=$(get_cjhubURI_name "$CJID" "$pid" "$filename")
UPLOAD_LOG_FILE=$(get_upload_log_filename "$CJID" "$pid" "$filename")


if [[ ! -f $CJHUB_URI_FILE ]] ; then 
  cjhub_message "Creating loc url for $pid/$filename"
  create_session_uri "$CJID" "$pid" "$filename"
else
  cjhub_message "Retreiving loc url to resume $pid/$filename"
fi

sessions_uri="`cat $CJHUB_URI_FILE`"

# if the location url exists this  gives 308
FILE="$pid/"$filename
get_status $session_uri $FILE "http_code" "range" > $UPLOAD_LOG_FILE 2>&1

echo $http_code
echo $range
while [[ ! $http_code -eq 200  ]]; do 
  cjhub_message "$FILE: UPLOADING"   
  upload_file "$session_uri" $FILE "$range" > $UPLOAD_LOG_FILE 2>&1
  
  # exponential delay if it cant get status due to network error
  for (( i=0 ; i < 8 ; i++ )); do
    get_status $session_uri $FILE "http_code" "range" > $UPLOAD_LOG_FILE 2>&1
    if [[ $http_code -eq 308 ]] || [[ $http_code -eq 200 ]] ; then
      break
    else
      wait=$((2**i))
      cjhub_message "Cannot get status. Next try after "$wait" sec..."
      sleep "$wait"   
    fi
  done

  [[ $http_code -eq 200 ]] && cjhub_message "UPLOAD COMPLETED" && break;
  [[ $http_code -gt 400 ]] && cjhub_message "Aborted HTTP_ERROR $http_code " && break;

done

