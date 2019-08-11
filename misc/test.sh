max()
{
local m="$1"
for n in "$@"; do
[ "$n" -gt "$m" ] && m="$n"
done
echo "$m"
}




min()
{
local m="$1"
for n in "$@"; do
[ "$n" -lt "$m" ] && m="$n"
done
echo "$m"
}




unique()
{
local uniq;
uniq=($(printf "%s\n" "$@" | sort -u));
echo "${uniq[*]}"
}

mode()
{
local m;

local uniq=($(unique "$@"))
length=${#uniq[@]}
declare -a count_arr=( $(for i in {0..$length}; do echo 0; done) )

m=${uniq[0]}

for (( i=0; i< $length ; i++ )) ;do
        this=${uniq[$i]}

        for s in $@;do
        [ "$s" -eq "$this" ] && count_arr[$i]=$(( ${count_arr[$i]} + 1 ))
        done

        [ ${count_arr[$i]} -gt "$m" ] && m=$this;

done

#echo "${count_arr[*]}"
echo "$m ${count_arr[*]}";
}






declare -a ARR
ARR[0]=1
ARR[1]=6
ARR[2]=6
ARR[3]=6

echo ${ARR[@]}
#max ${ARR[@]}
#min ${ARR[@]}
#unique ${ARR[@]}
#mode ${ARR[@]}
read mod count_arr < <(mode ${ARR[@]})
echo $mod
echo $count_arr





