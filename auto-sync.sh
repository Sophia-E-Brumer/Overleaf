#! /bin/bash
# drive-daemon
# Script for `drive push` automatically upon file update
# Written by davidhcefx, 13,Feb,2018
# source: https://github.com/odeke-em/drive/issues/446

watch0=
file0=
modifying=false
lastmodtime=0
lastmodfile=/null
exec 1>>~/drived.log   # Change to where you want to store log file
exec 2>&1
cd ~/SEB/refs_master  # Change to your own path

# You can add more ignore rules using the "--exclude" option of inotifywait
inotifywait -m -e create -e delete -e move -e modify -e attrib --exclude '.swp$' --exclude '.bak$' -r ./ | \
while read watch event file; do
	printf "\n$(date +%F\ %T): $watch $event $file\n"
	case $event in
	MODIFY)
		# Check if already modifying. If it is, push every 3 sec. (max rate)
		sec=`date +%s`
		if ! $modifying; then
			git push -no-prompt $watch$file
			modifying=true
			lastmodtime=$sec
			lastmodfile=$watch$file
		else
			if (( lastmodtime <= sec-3 )); then
				git push -no-prompt $watch$file
				lastmodtime=$sec
				lastmodfile=$watch$file
			elif [ "$lastmodfile" != "$watch$file" ]; then
				# Also push if modifying different files
				git push -no-prompt $lastmodfile $watch$file
				lastmodtime=$sec
				lastmodfile=$watch$file
			fi
		fi
	;;
	*)
		# Push when switching from modifying to non-modifying
		if $modifying; then
			drive push -no-prompt $watch$file
			modifying=false
		fi
	;;
	esac
	case $event in
	CREATE*)
		git push -no-prompt $watch$file
	;;
	DELETE*)
		git trash -quiet $watch$file
	;;
	MOVED_FROM*)
		# Store filename and it's path
		watch0=$watch
		file0=$file
	;;
	MOVED_TO*)
		if [ $watch0 != $watch ]; then  # file moved
			git move $watch0$file0 $watch
		fi
		if [ $file0 != $file ]; then  # file renamed
			git rename -local=0 $watch$file0 $watch$file
		fi
	;;
	ATTRIB)  # triggered when i.e. chmod
		git push -no-prompt $watch$file
	;;
	esac
done
