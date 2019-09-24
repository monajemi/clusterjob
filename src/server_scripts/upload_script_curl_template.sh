#!/bin/bash
# upload script for uploading CJ packages to
# CJHub

CJID="moosh"








# get status that location url exists
get_status(){

local LOCATION_URL=$1
local FILENAME=$2

local FILESIZE=$(wc -c $FILENAME | awk '{print $1}')


# make an empty query
local code=$(curl -v -w "%{http_code}" -X PUT -H 'Content-Length: 0' -H 'Content-Type: application/json' -H 'Content-Range: bytes */'$FILESIZE'' -d '' -o /dev/null $LOCATION_URL)

# you can give an input for range of upload as well
if [ $# -eq 3 ] ; then
  # calculate range
  myrange=0
  local __range=$3
  eval $__range=$myrange
fi

echo $code 
}




upload_file(){
#upload a given file and echo status


local LOCATION_URL=$1
local FILE=$2
local __httpcode=$3 


local http_code=$(get_status $LOCATION_URL $FILE)
eval $__httpcode=$http_code


if [[ $http_code -eq "308" ]] ; then 
# resume upload

  cjhub_message "$FILE : RESUMING!"
  
 curl -sv -X PUT --upload-file $FILE $LOCATION_URL >$UPLOAD_LOG_FILE 2>&1
  
  if [[ $? -ne 0 ]] ; then
    # detected error
    cat $UPLOAD_LOG_FILE
    echo "     CJHub: $FILE : ERROR" 
    exit 1;
  fi

elif [[ $http_code -eq 200 ]]; then
    echo "     CJHub: $FILE : COMPLETE!"
else
    echo "     CJHub: HTTP code $http_code not recognized."
fi
}



create_location_url() {
# variables that go into the cloud function
# getSignedResUrl to get a location url
# ex. 
#   get_location_url CJID PID FILENAME 
#   location_url=$(get_location_url moosh somedir test.tar)
#echo $location_url


local CJID=$1
local PID=$2
local FILENAME=$3
# execute a function call for resumable url
# FIXME: This must require CJKey, otherwise, anyone can get an upload url
local LOCATION_URL=$(curl -X POST -H 'Content-Type: application/json' -d '{"pid":"'$PID'","cj_id":"'$CJID'","filename":"'"$FILENAME"'"}' 'https://us-central1-testcj-12345.cloudfunctions.net/getSignedResUrl' 2>$UPLOAD_LOG_FILE) 

if [[ ! -z $LOCATION_URL ]]; then
        echo $LOCATION_URL > $(get_cjhubloc_name "$CJID" "$PID" "$FILENAME")
else
      cat $UPLOAD_LOG_FILE
      cjhub_message "Failed to create upload location url for $PID/$FILENAME" 
      exit 1;
fi

}

rm_extension(){
local fullfile=$1
local filename=$(basename -- "$fullfile")
#local extension="${filename##*.}"
filename="${filename%.*}"
echo $filename
}

get_cjhubloc_name(){

local CJID=$1
local pid=$2
local filename=$3
echo ".cjhubloc_"$CJID"_"$pid"_"$(rm_extension "$filename")
}

get_upload_log_filename() {
 echo ".upload_log_"$CJID"_"$pid"_"$(rm_extension "$filename")".txt"
}




cjhub_message(){
echo "          CJhub: $@"
}

#filename="test.tar"

pid="somedir"
filename="0854a767f859fda5b879edc8f49634f1cf58bfba.tar"
# exec upload
CJHUBLOC_FILE=$(get_cjhubloc_name "$CJID" "$pid" "$filename")
UPLOAD_LOG_FILE=$(get_upload_log_filename "$CJID" "$pid" "$filename")

if [[ ! -f $CJHUBLOC_FILE ]] ; then 
  cjhub_message "Creating loc url for $pid/$filename"
  create_location_url "$CJID" "$pid" "$filename"
else
  cjhub_message "Retreiving loc url to resume $pid/$filename"
fi

location_url="`cat $CJHUBLOC_FILE`"
upload_file "$location_url" "$pid/"$filename "code"

#code=308
#while [[ $code -eq 308 ]];do
#  upload_file $location_url "somedir/"$filename code
#  echo $code
#done

