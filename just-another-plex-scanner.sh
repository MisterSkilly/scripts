#!/bin/bash
# https://github.com/MisterSkilly/scripts
# This script finds new files from your plex libraries and issues a CLI scan for them.
# Useful in setups where Plex's automatic scan-on-new-files doesnt work such as network mounts.
# Run this with flock on cron, as often as you like.
#


echo "#####   Starting Just Another Plex Scanner  - $(date "+%d.%m.%Y %T") ####"

CACHE="$HOME/.cache/japs"
MOVIESECTION=4
MOVIELIBRARY="/path/to/your/plex/movie/library"
TVSECTION=3
TVLIBRARY="/path/to/your/plex/tv/library"

export LD_LIBRARY_PATH=/usr/lib/plexmediaserver
export PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR=/var/lib/plexmediaserver/Library/Application\ Support

mkdir -p "$CACHE"

### ATTENTION: Right now I'm running this script on a different (Plexdrive 5) mount in order to minimize stress on main mount.
###            Later in this script I am replacing the path of the temp mount with the main mount path, so that Plex finds the files.
###            If you don't care about the stress on your main mount, before the Plex scans remove the lines which replace the path.

echo "Listing movie files..."
find "$MOVIELIBRARY" -type f -not -name "*.srt" > "$CACHE/movies_files"
echo "Listed movie files"
echo "Listing tv files..."
find "$TVLIBRARY" -type f -not -name "*.srt" > "$CACHE/tv_files"
echo "Listed tv files"

echo "Sorting files..."
sort $CACHE/movies_files > $CACHE/movies_files_sorted
sort $CACHE/tv_files > $CACHE/tv_files_sorted
echo "Sorted files"

echo ""

if [ -s "$CACHE/movies_files_sorted" ]
then
    echo "There are movies (mount is not broken)"

    echo "Finding new movies..."

    touch $CACHE/movies_to_scan

    while read -r mfile
    do
        echo "$(date "+%d.%m.%Y %T") New file detected: $mfile"
        MFOLDER=$(dirname "${mfile}")
        echo "$MFOLDER" >> $CACHE/movies_to_scan
    done < <(comm -13 $CACHE/movies_files_sorted_old $CACHE/movies_files_sorted)

    sort $CACHE/movies_to_scan | uniq | tee $CACHE/movies_to_scan

    if [ -s "$CACHE/movies_to_scan" ]
    then
        echo "Found new movies"
        echo "Starting plex movies scan..."
        
        #aborting if exit != 0
        set -e
        
        readarray -t MOVIES < "$CACHE/movies_to_scan"
        for MOVIE in "${MOVIES[@]}"
        do
            # REPLACING TEMP MOUNT WITH MAIN MOUNT
#            MOVIE="${MOVIE/media/unionfs}"
#            MOVIE="${MOVIE/tmp/sorted}"
            echo "Scanning movie \"$( basename "$MOVIE" )\" on dassdi..." | /home/skilly/scripts/telegram/telegram-pipe-plexrefresh.sh
            echo "$(date "+%d.%m.%Y %T") Plex scan movie folder:: $MOVIE"
            $LD_LIBRARY_PATH/Plex\ Media\ Scanner --scan --refresh --section "$MOVIESECTION" --directory "$MOVIE"
        done
        
        set +e
        echo "Plex movies scan finished"
        echo "Preparing cache files for next scan..."
        
        mo=$( wc -c "$CACHE/movies_files_sorted_old" | awk '{print $1}' )
        mn=$( wc -c "$CACHE/movies_files_sorted" | awk '{print $1}')
        #echo $mo
        #echo $mn
        if (( $(( $mn + 3000 )) > $mo )); then
            echo "Updating movies file"
            mv $CACHE/movies_files_sorted $CACHE/movies_files_sorted_old
        else
            echo "New movies file is significantly smaller, assuming something broke and not updating movies file."
            rm $CACHE/movies_files_sorted
        fi
        
        
    else
        echo "No new movies found"
        
    fi

else
        echo "There are no movies (mount is likely broken, aborting movies scan)"
fi

echo ""

rm $CACHE/movies_files
rm $CACHE/movies_to_scan
rm $CACHE/movies_files_sorted

if [ -s "$CACHE/tv_files_sorted" ]
then
    echo "There are TV files (mount is not broken)"

    echo "Finding new TV files..."

    touch $CACHE/tv_to_scan

    while read -r tvfile
    do
        echo "$(date "+%d.%m.%Y %T") New file detected: $tvfile"
        MFOLDER=$(dirname "${tvfile}")
        echo "$MFOLDER" >> $CACHE/tv_to_scan
    done < <(comm -13 $CACHE/tv_files_sorted_old $CACHE/tv_files_sorted)

    sort $CACHE/tv_to_scan | uniq | tee $CACHE/tv_to_scan

    if [ -s "$CACHE/tv_to_scan" ]
    then
        echo "Found new TV files"
        echo "Starting plex TV scan..."

        #aborting if exit != 0
        set -e

        readarray -t FOLDERS < "$CACHE/tv_to_scan"
        for FOLDER in "${FOLDERS[@]}"
        do
            # REPLACING TEMP MOUNT WITH MAIN MOUNT
 #           FOLDER="${FOLDER/media/unionfs}"
  #          FOLDER="${FOLDER/tmp/sorted}"
            echo "Scanning TV show \"$( basename "$( dirname "$FOLDER" )" )\" on dassdi..." | /home/skilly/scripts/telegram/telegram-pipe-plexrefresh.sh
            echo "$(date "+%d.%m.%Y %T") Plex scan TV folder:: $FOLDER"
            $LD_LIBRARY_PATH/Plex\ Media\ Scanner --scan --refresh --section "$TVSECTION" --directory "$FOLDER"
        done

        set +e
        echo "Plex TV scan finished"
        echo "Preparing cache files for next scan..."

        to=$( wc -c "$CACHE/tv_files_sorted_old" | awk '{print $1}' )
        tn=$( wc -c "$CACHE/tv_files_sorted" | awk '{print $1}')
        if (( $(( $tn + 3000 )) > $to )); then
            echo "Updating TV file"
            mv $CACHE/tv_files_sorted $CACHE/tv_files_sorted_old
        else
            echo "New TV file is significantly smaller, assuming something broke and not updating TV file."
            rm $CACHE/tv_files_sorted
        fi


    else
        echo "No new TV files found"

    fi


else
        echo "There are no TV files (mount is likely broken, aborting TV scan)"
fi

rm $CACHE/tv_to_scan
rm $CACHE/tv_files
rm $CACHE/tv_files_sorted


echo "##### Just Another Plex Scanner is finished - $(date "+%d.%m.%Y %T") ####"
echo "#########################################################"