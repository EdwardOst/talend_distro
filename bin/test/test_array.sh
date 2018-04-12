declare -A mydict=( [key1]=value1 [key2]=value2 )


echo "keys: ${!mydict[@]}"
echo "values: ${mydict[@]}"
declare mykey=key1
echo "mykey=${mykey}"
echo "mydict[mykey]: ${mydict[${mykey}]}"
