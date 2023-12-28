#!/bin/bash
# wget https://raw.githubusercontent.com/Vahhhh/solana/main/linux_performance.sh | bash
sudo apt-get install cpufrequtils -y && \
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils && \
sudo systemctl disable ondemand && \
sudo systemctl restart cpufrequtils.service
