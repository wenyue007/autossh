#!/bin/bash -
#Author: hujianwei00007@163.com
#Date: 2015/12/5
#Version: v1.0

expect_re=`expect -h &> /dev/null;echo $?`
server_ip=$1
account=${2:-wrsadmin}
passwdd=${3:-kernel}

#In this function, we need input the peer password at least one time.
keys()
{
    echo -e "\033[34mRunning ssh-keygen/ssh-add ...[y]\033[0m"
    [ -f ~/.ssh/id_rsa.pub ] || 
        if [ "$expect_re" -eq 1 ]; then
        {
            echo "Using expect way to generate key..."
            expect <<- END
            spawn ssh-keygen -t rsa
            expect "Enter file in which to save the key" 
            send "\r"
           
            expect "Enter passphrase (empty for no passphrase):"
            send "\r"
           
            expect  "Enter same passphrase again:"       
            send "\r"
            	
            expect eof
            exit
END
        }
     else
        echo "Using ssh-keygen way to generate key..."
        ssh-keygen -q
    fi
    ssh-add ~/.ssh/id_rsa > /dev/null 2>&1

    ssh-keygen -R $server_ip &> /dev/null
    [ -z "$account" -o -z "$server_ip" ] && { echo "Null for ip or account"; continue;}
    echo -e "\033[34m>>>>On $account at $server_ip :\033[0m"
    echo "Try to connect it..."
    ping $server_ip -c 3  > /dev/null 2>&1 && echo -e "\033[32mSuccess to connect it\033[0m "|| { echo -e "\033[31mFailed to connect it\033[0m"; continue;}
 
    ssh -n -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=0 ${account}@$server_ip "ls -l" > tmp.log 2>&1
    r=`cat tmp.log | grep -E "Permission denied|Connection refused|Too many authentication failures" > /dev/null 2>&1;echo $?`
    [ $r -ne 0 ] && { echo -e "\033[32mAlready pass to login without password!\033[0m"; rm -rf tmp.log; checker;exit 0;}
    rm -rf tmp.log
 
    type ssh-copy-id >/dev/null 2>&1
    re_id=`echo $?`
    if [ "$re_id" -eq 0 ]; then
        if [ "$expect_re" -eq 1 ]; then
            echo "Using expect way to execute ssh-copy-id..."
            expect <<- END
            spawn  ssh-copy-id -o StrictHostKeyChecking=no ${account}@$server_ip
            expect "Password"
            send "${passwdd}\r"
            expect eof
            exit
END
        else
            echo "You may input password for ssh-copu-id command..."
            ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${account}@$server_ip >/dev/null 2>&1
        fi
    else
        echo -e "\033[34m[Please input password] Using tradition scp type...\033[0m"
        echo -e "\033[34mscp ~/.ssh/id_rsa.pub to peer server\033[0m"
        scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa.pub ${account}@${server_ip}:~
        echo -e "\033[34mcat id_rsa.pub into authorized_keys in peer server\033[0m"
        ssh -n -o StrictHostKeyChecking=no -n ${account}@$server_ip "cat ~/id_rsa.pub  >> ~/.ssh/authorized_keys"
        echo -e "\033[34mchange authorized_keys mode to 600 in peer server\033[0m"
        ssh -n ${account}@$server_ip "chmod 600 ~/.ssh/authorized_keys"
    fi
    echo -e "\033[34mDone for '$account' on '$server_ip' autossh login\033[0m"
}

checker()
{
    sleep 1
    ssh -n ${account}@$server_ip "ls -l --color"
}

pusher()
{
    have=`eval ssh -n ${account}@$server_ip 'ls $0 > /dev/null 2>&1 ;echo $?'`
    [ 0 -ne "$have" ] && scp $0 ${account}@$server_ip:~
}

[ -z $server_ip ] && { 
                      echo "Please input peer IP"
                      exit 1
                     }
keys
echo -e "\033[34mOn $account at $server_ip\033[0m"
checker
pusher
