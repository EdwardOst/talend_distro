echo "trap -- 'rm -rf /tmp/tmp.Nj6DdwBwNJ' EXIT"
echo "trap -- 'rm -rf /tmp/tmp.Nj6DdwBwNJ' EXIT" | awk -F"'" '{ print $2 }'
#echo "a b c d" | awk '{ print $2 }'

