#!/bin/sh

while [ 1 ]
do
    mkdir -p /var/log/php_fpm
    try_count=1
    d_php_fpm=`top -b -n 1 | grep php-fpm | grep D | wc -l`
    if [ $d_php_fpm -ne 0 ]; then
        # STAT D php_fpm exist.
        # echo "========================================"
        # date >> /var/log/php_fpm/watch.log
        # top -b -n 1 | grep php_fpm >> /var/log/php_fpm/watch.log
        while [ $try_count -le 5 ]
        do
            sleep 3s
            let try_count+=1
            d_php_fpm=`top -b -n 1 | grep php-fpm | grep D | wc -l`
            # echo "========================================"
            # date >> /var/log/php_fpm/watch.log
            # top -b -n 1 | grep php_fpm >> /var/log/php_fpm/watch.log
            if [ $d_php_fpm -eq 0 ]; then
                break
            fi
        done
        if [ $try_count -ge 5 ]; then
            # echo "========================================"
            # date >> /var/log/php_fpm/watch.log
            # echo "Start to KILL!"
            # # STAT D has keep for 15 secs.
            killall -9 php-fpm
            killall -9 nginx  
        fi    
    fi
    sleep 3s
done