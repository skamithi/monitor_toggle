#!/bin/bash
# 2006-03-09 <pille@struction.de>
#
# displays text in arguments on X screen using osd_cat (in some nicely preconfigured style)

OSD_CAT=`which osd_cat`
XOSD="${OSD_CAT} --delay=4 --age=0 --lines=1 --pos=bottom --align=left --font=-adobe-times-bold-r-normal-*-*-400-*-*-p-*-*-* --colour=#45f100 --shadow=1 --offset=25 --indent=25"

# get user running X display (needed when run by script)
for x in /tmp/.X11-unix/*; do
  displaynum=`echo $x | sed s#/tmp/.X11-unix/X##`
  xuser=`finger| grep -m1 ":$displaynum " | awk '{print $1}'`
  if [ x"$xuser" = x"" ]; then
        xuser=`finger| grep -m1 ":$displaynum" | awk '{print $1}'`
   fi
done

echo $xuser

if [ "${USER}" == "${xuser}" ]; then
    echo $@ | ${XOSD}
else
    echo $@ |su ${xuser} -c "DISPLAY=${DISPLAY:-:0.0} ${XOSD}"
fi
