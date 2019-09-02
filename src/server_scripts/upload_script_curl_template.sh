#!/bin/bash
# upload script for uploading CJ packages to
# CJHub





# get status that location url exists
get_status(){

local LOCATION_URL=$1
local FILENAME=$2

local FILESIZE=$(wc -c $FILENAME | awk '{print $1}')


# make an empty query
local code=$(curl -v -w "%{http_code}" -X PUT -H 'Content-Length: 0' -H 'Content-Type: application/json' -H 'Content-Range: bytes */'$FILESIZE'' -d '' -o /dev/null $LOCATION_URL)

# you can give an input for range as well
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

  echo "     CJHub: $FILE : RESUMING!"
  
  # FIXME: make name file dependent
  local logname="upload_log.txt"
  touch $logname
  curl -sv -X PUT --upload-file $FILE $LOCATION_URL > $logname 2>&1
  
  if [[ $? -ne 0 ]] ; then
    # detected error
    cat $logname 
    echo "     CJHub: $FILE : ERROR" 
    exit 1;
  fi

elif [[ $http_code -eq 200 ]]; then

    echo "     CJHub: $FILE : COMPLETE!"

else
    echo "     CJHub: HTTP code $http_code not recognized."
fi
}


get_location_url() {
# variables that go into the cloud function
# getSignedResUrl to get a location url
# ex. 
#   get_location_url CJID PID FILENAME 
#   location_url=$(get_location_url moosh somedir test.tar)
#echo $location_url

CJID=$1
local PID=$2
local FILENAME=$3

# execute a function call for resumable url
local LOCATION_URL=$(curl -X POST -H 'Content-Type: application/json' -d '{"pid":"'$PID'","cj_id":"'$CJID'","filename":"'"$FILENAME"'"}' 'https://us-central1-testcj-12345.cloudfunctions.net/getSignedResUrl' 2>/dev/null )

# if error exit
if [ $? -eq 0 ]; then
    echo $LOCATION_URL > .cjhubloc
else
    echo $LOCATION_URL
    exit 1;
fi
}









#filename="test.tar"
filename="0854a767f859fda5b879edc8f49634f1cf58bfba.tar"
# exec upload
[[ ! -f '.cjhubloc' ]] && location_url=$(get_location_url moosh somedir $filename)

location_url="`cat .cjhubloc`"
upload_file $location_url "somedir/$filename" code

#code=308
#while [[ $code -eq 308 ]];do
#  upload_file $location_url "somedir/"$filename code
#  echo $code
#done






