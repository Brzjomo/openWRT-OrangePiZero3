#!/bin/bash
# Tested On Ubuntu 22.04
# 安装编译依赖环境
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz \
mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pyelftools \
libpython3-dev qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip \
vim wget xmlto xxd zlib1g-dev

# 克隆lede
git clone https://github.com/coolsnowwolf/lede

if [ ! -d "lede" ]; then
  echo "lede文件夹不存在, 可能是下载失败"
  exit 0
fi

cd lede

# 修改默认主机名
sed -i '/uci commit system/i\uci set system.@system[0].hostname='OpenWrt-opz3'' package/lean/default-settings/files/zzz-default-settings

# 分配静态IP
sed -i '/uci commit system/a uci set network.lan.ipaddr='\''192.168.50.80'\''\nuci set network.lan.proto='\''static'\''\nuci set network.lan.type='\''bridge'\''\nuci set network.lan.ifname='\''eth0'\''\nuci set network.lan.netmask='\''255.255.255.0'\''\nuci set network.lan.gateway='\''192.168.50.1'\''\nuci set network.lan.dns='\''192.168.50.1'\''\nuci commit network' package/lean/default-settings/files/zzz-default-settings

# 添加三个库
sed -i '$a\
src-git kenzo https://github.com/kenzok8/openwrt-packages\
src-git small https://github.com/kenzok8/small\
src-git realtek https://github.com/Pix13/openwrt-rtw88-usb-feed' feeds.conf.default

# 移除要替换的包
rm -rf feeds/luci/themes/luci-theme-argon

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 科学上网插件
git clone --depth=1 https://github.com/fw876/helloworld package/luci-app-ssr-plus
#git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall package/luci-app-passwall
# git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash

# Themes
git clone --depth=1 -b 18.06 https://github.com/kiddin9/luci-theme-edge package/luci-theme-edge
git clone --depth=1 -b 18.06 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom package/luci-theme-infinityfreedom
git_sparse_clone main https://github.com/haiibo/packages luci-theme-atmaterial luci-theme-opentomcat luci-theme-netgear

# 更改 Argon 主题背景
cp -f ../images/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# 修复 hostapd 报错
cp -f ../scripts/011-fix-mbo-modules-build.patch package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch

# 修复 armv8 设备 xfsprogs 报错
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# 修复 rtl8812au-ac 驱动编译报错
cp -f ../scripts/050-backport-6.1.patch package/kernel/rtl8812au-ac/patches/050-backport-6.1.patch

# 修改 Makefile
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 取消主题默认设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

./scripts/feeds update -a
./scripts/feeds install -a

make menuconfig
