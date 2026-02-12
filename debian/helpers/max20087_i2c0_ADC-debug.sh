#!/bin/bash

# Script disable-enable max20087 Power-over-Coax GMSL A/B/C/D on bus 0, address 0x28
# Usage: ./i2c_register_dump.sh

BUS=0
ADDR=0x28
CONFIG=0x01
START_REG=0x06
END_REG=0x09

echo "max20087 I2C Register Dump"
echo "Bus: $BUS"
echo "Address: $ADDR"
echo "Register range: 0x$(printf "%02X" $START_REG) - 0x$(printf "%02X" $END_REG)"
echo "----------------------------------------"

# Check if i2ctransfer is available
if ! command -v i2ctransfer &> /dev/null; then
    echo "Error: i2ctransfer command not found. Please install i2c-tools package."
    exit 1
fi

# Function to read a 8-bit register
read_register() {
    local reg=$1
    local reg_low=$((reg & 0x7F))
    
    # Write register address (16-bit) and read 1 byte
    # Format: w2@addr reg_high reg_low r1
    local result=$(i2ctransfer -f -y $BUS w1@$ADDR 0x$(printf "%02X" $reg_low) r1 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "0x$(printf "%02X" $reg): $result"
    else
        echo "0x$(printf "%02X" $reg): ERROR"
    fi
}

v="$(i2ctransfer -f -y $BUS w1@$ADDR $CONFIG r1)"

v=$(( $v & ~(0xE0) )) # Clear ADC
v=$(( $v | (0xA0) )) # Enable ADC cont In-voltage,

i2ctransfer -f -y $BUS w2@$ADDR $CONFIG $v

sleep 0.5  # 500ms delay

read_register $CONFIG

# Main loop to iterate through all registers
echo "max20087 Voltage-In ADC  continuous-read"
for ((reg=$START_REG; reg<=$END_REG; reg++)); do
    read_register $reg
    
    # Add a small delay to avoid overwhelming the device
    # Remove or adjust this if faster operation is needed
    sleep 0.001  # 1ms delay
    
done

v=$(( $v & ~(0xE0) )) # Clear ADC
v=$(( $v | (0x60) )) # Enable ADC cont out-voltage,

i2ctransfer -f -y $BUS w2@$ADDR $CONFIG $v
echo "----------------------------------------"

sleep 0.5  # 500ms delay
read_register $CONFIG

# Main loop to iterate through all registers
echo "GMSL Voltage-out ADC continuous-read"
for ((reg=$START_REG; reg<=$END_REG; reg++)); do
    read_register $reg
    
    # Add a small delay to avoid overwhelming the device
    # Remove or adjust this if faster operation is needed
    sleep 0.001  # 1ms delay
    
done

v=$(( $v & ~(0xE0) )) # Clear ADC
v=$(( $v | (0x30) )) # Enable ALL Vout, ADC Iout
i2ctransfer -f -y $BUS w2@$ADDR $CONFIG $v

echo "----------------------------------------"
sleep 0.5  # 500ms delay
read_register $CONFIG

# Main loop to iterate through all registers
echo "GMSL Current-out ADC continuous-read"
for ((reg=$START_REG; reg<=$END_REG; reg++)); do
    read_register $reg
    
    # Add a small delay to avoid overwhelming the device
    # Remove or adjust this if faster operation is needed
    sleep 0.001  # 1ms delay
    
done

v=$(( $v & ~(0xE0) )) # Clear ADC
i2ctransfer -f -y $BUS w2@$ADDR $CONFIG $v

echo "----------------------------------------"
echo "Register dump completed."
