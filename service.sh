#!/bin/bash

case $1 in
  "start" )
    echo start
    nohup bundle exec ruby hi.rb > ./01.log &
    ;;
  "stop" )
    echo stop
    ps aux | grep ruby | grep hi.rb| awk '{print $2}'|xargs kill -9
    ;;
  "restart" )
    echo restart
    ps aux | grep ruby | grep hi.rb| awk '{print $2}'|xargs kill -9
    nohup bundle exec ruby hi.rb > ./01.log &
esac
