#!/bin/bash
#
# Compile script for kernel
#

# Initialize flags for options
clean=false
local=false
# oss_only=false
oss_only=true

# Use getopt for parsing long and short options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--clean)
      clean=true
      shift
      ;;
    -l|--local)
      local=true
      shift
      ;;
    --oss-only)
      oss_only=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

SECONDS=0 # builtin bash timer

ZIPNAME="[MIUI][11-13]STRIX-sweet-revival-$(date '+%Y%m%d').zip"

export ARCH=arm64
export KBUILD_BUILD_USER=vbajs
export KBUILD_BUILD_HOST=tbyool

if [ ! -d "$PWD/clang" ]; then
	aria2c -k 1M -s 8 -x 8 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r530567.tar.gz
	mkdir clang && tar -xvf clang-r530567.tar.gz -C clang && rm -rf clang-530567.tar.gz
else
	echo "Local clang dir found, will not download clang and using that instead"
fi

export PATH="$PWD/clang/bin/:$PATH"
export KBUILD_COMPILER_STRING="$($PWD/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

if [ "$local" = true ]; then
	echo -e "\nLocal build, disabling LTO...\n"
	patch -p1 < local-build.patch
fi

if [ "$clean" = true ]; then
	rm -rf out
	echo "Cleaned output folder"
fi

echo -e "\nStarting compilation...\n"
make O=out ARCH=arm64 vendor/sweet_defconfig
make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ] || [ ! -f "$dtb" ]; then
	echo -e "\nCompilation failed!"
	exit 1
fi

echo "\nDone compiling KSU, now compiling with disabled KSU..\n"



if [ "$oss_only" = true ]; then
	echo -e "\nNot compiling other DTBO..."
	echo -e "\nKernel compiled successfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	else
		if ! git clone -q https://github.com/vbajs/AnyKernel3.git -b fiqri AnyKernel3; then
			echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
			exit 1
		fi
	fi
	sed -i "s/supported\.versions=.*/supported.versions=11-14/" Anykernel3/anykernel.sh
	cp $kernel AnyKernel3
	cp $dtbo AnyKernel3
	cp $dtb AnyKernel3
	cd AnyKernel3
	zip -r9 "../$ZIPNAME" * -x .git README.md
	cd ..
	rm -rf AnyKernel3
	if [ "$local" = true ]; then
		git restore arch/arm64/configs/vendor/sweet_defconfig
	else
		if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
		   head=$(git rev-parse --verify HEAD 2>/dev/null); then
		        HASH="$(echo $head | cut -c1-8)"
		fi
		./telegram -f $ZIPNAME -C "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) ! Latest commit: $HASH !!WARNING!! 1 DTBO Only build!"
	fi
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
	exit 0
fi

echo -e "\nCompiled Kernel + OSS dimensions, now compiling MIUI dimensions while dirty.."
mkdir ./out/arch/arm64/boot/oss/
cp $dtbo out/arch/arm64/boot/oss/dtbo.img
ossdtbo="out/arch/arm64/boot/oss/dtbo.img"
rm -rf $dtbo
patch -p1 < miui-dtbo.patch
make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

if [ ! -f "$dtbo" ]; then
	echo -e "\nCompilation failed!"
	exit 1
fi

echo -e "\nKernel compiled successfully! Zipping up...\n"
mkdir ./out/arch/arm64/boot/miui/
cp $dtbo out/arch/arm64/boot/miui/dtbo.img
miuidtbo="out/arch/arm64/boot/miui/dtbo.img"

if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
else
	if ! git clone -q https://github.com/vbajs/AnyKernel3.git -b exp-fiqri AnyKernel3; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
fi

cp $kernel AnyKernel3
cp $ossdtbo AnyKernel3/dtbo/oss
cp $miuidtbo AnyKernel3/dtbo/miui
cp $dtb AnyKernel3
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git README.md
cd ..
rm -rf AnyKernel3
git restore arch/arm64/boot/dts/qcom/dsi-panel-k6-38-0c-0a-fhd-dsc-video.dtsi
if [[ "$local" = true ]]; then
	git restore arch/arm64/configs/vendor/sweet_defconfig
fi
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	HASH="$(echo $head | cut -c1-8)"
fi

if [ "$local" = false ]; then
	./telegram -f $ZIPNAME -C "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) ! Latest commit: $HASH"
fi
