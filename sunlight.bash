#!/bin/bash

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Look for a config file in the current directory
if [ -s $current_dir/sunlight.conf ] ; then
    . $current_dir/sunlight.conf
elif [ -s $current_dir/sunlight-default.conf ] ; then 
    . $current_dir/sunlight-default.conf
else 
    echo "Neither $current_dir/sunlight.conf nor $current_dir/sunlight-default.conf found, aborting sunlight"
    # Caution: Use return here, not exit, otherwise you will exit bash session
    return
fi


# http://www.gnu.org/software/bash/manual/html_node/Bash-History-Builtins.html#Bash-History-Builtins
# We are going to store each session as a separate file
bash_hist=$HIST_DIR/$USER 
sship=`echo $SSH_CLIENT | awk '{print $1}'`
test -d $bash_hist || mkdir -p $bash_hist
export HISTFILE=$bash_hist/hist-$sship-`date +%Y-%m-%d-%H-%M-%S`.hist

# Notify upon login
mail_exists="`which mail`"
if [ "$SUNLIGHT_EMAIL_NOTIFY_LOGIN" != "" ]; then
    if [ "$mail_exists" == "" ] ; then
        echo "'mail' not installed, mail cannot be sent from Sunlight"
    else 
        echo "History will be recorded to $HISTFILE" | mail -s "$USER@$sship logged into `hostname -f`" $SUNLIGHT_EMAIL_NOTIFY_LOGIN
    fi
fi

# Set up logout notify
function sunlight_logout() {
    if [ "$SUNLIGHT_EMAIL_NOTIFY_LOGOUT" != "" ]; then
        tmphist=`mktemp /tmp/sunlight.XXXXXXXXXX`
        history -a $tmphist 
        cat $tmphist | mail -s "$USER@$sship logged out of `hostname -f`" $SUNLIGHT_EMAIL_NOTIFY_LOGOUT
        rm $tmphist
    fi
}

# Put the sunlight_logout call into ~/.bash_logout, if it doesn't already exist
bash_logout=$HOME/.bash_logout
if [ ! -f $bash_logout ] ; then 
    touch $bash_logout
fi
if [ "`grep ^sunlight_logout ~/.bash_logout`" == "" ] ; then 
    echo sunlight_logout >> $bash_logout
fi

# Clean up files based on $SUNLIGHT_MAX_DAYS
if [ "$SUNLIGHT_MAX_DAYS" != "" ] ; then
    find $bash_hist -mtime +$SUNLIGHT_MAX_DAYS | xargs rm -rf
fi

# Read in history from the previous history files, up until we hit HISTSIZE
for file in `ls -1tr $bash_hist`; do
    history -r $bash_hist/$file
    if [ `history | wc -l` -gt $HISTSIZE ] ; then
        break
    fi
done


# Display the login message
if [ "$SUNLIGHT_LOGIN_MESSAGE" != "" ] ; then
    echo $SUNLIGHT_LOGIN_MESSAGE
fi
