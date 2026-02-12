#!/bin/bash

# Script to dump i2c registers from 0x00 to 0x1271 on bus 1, address 0x27
# Usage: ./i2c_register_dump.sh

BUS=0
ADDR=0x27
START_REG=0x00
END_REG=0x1271

echo "I2C Register Dump"
echo "Bus: $BUS"
echo "Address: $ADDR"
echo "Register range: 0x$(printf "%04X" $START_REG) - 0x$(printf "%04X" $END_REG)"
echo "----------------------------------------"

# Check if i2ctransfer is available
if ! command -v i2ctransfer &> /dev/null; then
    echo "Error: i2ctransfer command not found. Please install i2c-tools package."
    exit 1
fi

# Function to read a 16-bit register
read_register() {
    local reg=$1
    local reg_high=$((reg >> 8))
    local reg_low=$((reg & 0xFF))
    
    # Write register address (16-bit) and read 1 byte
    # Format: w2@addr reg_high reg_low r1
    local result=$(i2ctransfer -f -y $BUS w2@$ADDR 0x$(printf "%02X" $reg_high) 0x$(printf "%02X" $reg_low) r1 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "0x$(printf "%04X" $reg): $result"
    else
        echo "0x$(printf "%04X" $reg): ERROR"
    fi
}

# Main loop to iterate through all registers
echo "Starting register dump..."
for ((reg=$START_REG; reg<=$END_REG; reg++)); do
    read_register $reg
    
    # Add a small delay to avoid overwhelming the device
    # Remove or adjust this if faster operation is needed
    sleep 0.001  # 1ms delay
    
    # Progress indicator every 256 registers
    if [ $((reg % 256)) -eq 0 ]; then
        echo "Progress: $reg / $END_REG registers completed"
    fi
done

echo "----------------------------------------"
echo "Register dump completed."
