#!/bin/sh

# Defined path
MainPath="$(pwd)"
GCC64="$(pwd)/../GCC64"
GCC="$(pwd)/../GCC"
Any="$(pwd)/../AnyKernel3"

# Make flashable zip
MakeZip() {
    if [ ! -d $Any ]; then
        git clone https://github.com/TeraaBytee/AnyKernel3 -b q-oss $Any
        cd $Any
    else
        cd $Any
        git reset --hard
        git checkout q-oss
        git fetch origin q-oss
        git reset --hard origin/q-oss
    fi
    cp -af $MainPath/out/arch/arm64/boot/Image.gz-dtb $Any
    sed -i "s/kernel.string=.*/kernel.string=$KERNEL_NAME-$HeadCommit test by $KBUILD_BUILD_USER/g" anykernel.sh
    zip -r9 $MainPath/"[$Compiler][Q-OSS]-$ZIP_KERNEL_VERSION-$KERNEL_NAME-$TIME.zip" * -x .git README.md *placeholder
    cd $MainPath
}

# Clone compiler
if [ ! -d $GCC64 ]; then
    git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 $GCC64
fi
if [ ! -d $GCC ]; then
    git clone --depth=1 https://github.com/mvaisakh/gcc-arm $GCC
fi

# Defined config
HeadCommit="$(git log --pretty=format:'%h' -1)"
export ARCH="arm64"
export SUBARCH="arm64"
export KBUILD_BUILD_USER="TeraaBytee"
export KBUILD_BUILD_HOST="$(hostname)"
Defconfig="begonia_user_defconfig"
KERNEL_NAME=$(cat "$MainPath/arch/arm64/configs/$Defconfig" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
ZIP_KERNEL_VERSION="4.14.$(cat "$MainPath/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')$(cat "$(pwd)/Makefile" | grep "EXTRAVERSION =" | sed 's/EXTRAVERSION = *//g')"
TIME=$(date +"%m%d%H%M")

# Start building
Compiler=GCC
MAKE="./makeparallel"
rm -rf out
BUILD_START=$(date +"%s")

make  -j$(nproc --all)  O=out ARCH=arm64 SUBARCH=arm64 $Defconfig
exec 2> >(tee -a out/error.log >&2)

make  -j$(nproc --all)  O=out \
                        PATH=$GCC64/bin:$GCC/bin:/usr/bin:${PATH} \
                        AR=aarch64-elf-ar \
                        LD=ld.lld \
                        OBJDUMP=aarch64-elf-objdump \
                        CROSS_COMPILE=aarch64-elf- \
                        CROSS_COMPILE_ARM32=arm-eabi-

if [ -e $MainPath/out/arch/arm64/boot/Image.gz-dtb ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    MakeZip
    echo "Build success in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
else
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    echo "Build fail in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
