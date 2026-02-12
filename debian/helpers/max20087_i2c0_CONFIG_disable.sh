#!/bin/bash

# Script disable-enable max20087 Power-over-Coax GMSL A/B/C/D on bus 0, address 0x28
# Usage: ./i2c_register_dump.sh

BUS=0
ADDR=0x28
MASK=0x00
CONFIG=0x01

# Check if i2ctransfer is available
if ! command -v i2ctransfer &> /dev/null; then
    echo "Error: i2ctransfer command not found. Please install i2c-tools package."
    exit 1
fi

# Function to read a 16-bit register
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

#v=$(( $v & ~(1) )) # Disable GMSL A
#v=$(( $v & ~(1<<1) )) # Disable GMSL B
#v=$(( $v & ~(1<<2) )) # Disable GMSL C
#v=$(( $v & ~(1<<3) )) # Disable GMSL D
v=$(( $v & ~(0xF) )) # Disable ALL
i2ctransfer -f -y $BUS w2@$ADDR $CONFIG $v

echo "Disable GSML 12V PoC"
read_register $CONFIG

echo "Clear MASK"
read_register $MASK

sleep 0.5

i2ctransfer -f -y $BUS w2@$ADDR $MASK 0x00
