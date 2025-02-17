#!/bin/bash

# Array of device names
#devices=("sweet" "courbet" "tucana" "toco" "phoenix" "davinci")
devices=("sweet")

# Loop through the devices
for device in "${devices[@]}"
do
    echo "Generating defconfig for $device"
    make ARCH=arm64 O=out "vendor/${device}"_defconfig
    make ARCH=arm64 O=out menuconfig
    cp out/.config "arch/arm64/configs/vendor/${device}_defconfig"
    rm -rf out
    echo "Defconfig generated for $device"
    echo ""
done

echo "Defconfig generation completed."
