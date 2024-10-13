#!/bin/bash
#
# Compile script for kernel
#

SECONDS=0 # builtin bash timer

# Allowed codenames
ALLOWED_CODENAMES=("sweet" "courbet" "tucana" "toco" "phoenix" "davinci")

# Prompt user for device codename
read -p "Enter device codename: " DEVICE

# Check if the entered codename is in the allowed list
if [[ ! " ${ALLOWED_CODENAMES[@]} " =~ " ${DEVICE} " ]]; then
    echo "Error: Invalid codename. Allowed codenames are: ${ALLOWED_CODENAMES[*]}"
    exit 1
fi

ZIPNAME="ksu-STRIX-${DEVICE}-revival-$(date '+%Y%m%d-%H%M').zip"

export ARCH=arm64
export KBUILD_BUILD_USER=vbajs
export KBUILD_BUILD_HOST=lhohq
export PATH="/home/vbajs/toolchains/zyc-clang/20.0.0git-20241001-release/bin/:$PATH"

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
	echo "Cleaned output folder"
fi

echo -e "\nStarting compilation for $DEVICE...\n"
make O=out ARCH=arm64 vendor/${DEVICE}_defconfig
make -j$(nproc) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ] || [ ! -f "$dtb" ]; then
	echo -e "\nCompilation failed!"
	exit 1
fi

echo -e "\nKernel compiled successfully! Zipping up...\n"

if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
else
	if ! git clone -q --depth=1 https://github.com/vbajs/AnyKernel3.git -b fiqri AnyKernel3; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
fi

# Modify anykernel.sh to replace device names
sed -i "s/device\.name1=.*/device.name1=${DEVICE}/" AnyKernel3/anykernel.sh
sed -i "s/device\.name2=.*/device.name2=${DEVICE}in/" AnyKernel3/anykernel.sh

cp $kernel AnyKernel3
cp $dtbo AnyKernel3/dtbo/oss
cp $dtb AnyKernel3
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git
cd ..
rm -rf AnyKernel3
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
