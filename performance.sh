#!/bin/bash
sudo apt-get install cpufrequtils -y && \
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils && \
sudo systemctl disable ondemand && \
sudo systemctl restart cpufrequtils.service
