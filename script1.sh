#/bin/sh
# Edit the /etc/apt/sources.list and replace the line "deb http://archive.ubuntu.com/ubuntu xenial main 
# restricted" with "deb http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse" and 
# then do a "sudo apt-get update" followed by "sudo apt-get install texinfo".

apt-get update

export LFS=/mnt/lfs

echo $LFS

/sbin/swapon -v /dev/sda2

cd $LFS

cat > version-check.sh << "EOF"
#!/bin/bash
# Simple script to list version numbers of critical development tools
export LC_ALL=C
bash --version | head -n1 | cut -d" " -f2-4
MYSH=$(readlink -f /bin/sh)
echo "/bin/sh -> $MYSH"
echo $MYSH | grep -q bash || echo "ERROR: /bin/sh does not point to bash"
unset MYSH

echo -n "Binutils: "; ld --version | head -n1 | cut -d" " -f3-
bison --version | head -n1

if [ -h /usr/bin/yacc ]; then
  echo "/usr/bin/yacc -> `readlink -f /usr/bin/yacc`";
elif [ -x /usr/bin/yacc ]; then
  echo yacc is `/usr/bin/yacc --version | head -n1`
else
  echo "yacc not found" 
fi

bzip2 --version 2>&1 < /dev/null | head -n1 | cut -d" " -f1,6-
echo -n "Coreutils: "; chown --version | head -n1 | cut -d")" -f2
diff --version | head -n1
find --version | head -n1
gawk --version | head -n1

if [ -h /usr/bin/awk ]; then
  echo "/usr/bin/awk -> `readlink -f /usr/bin/awk`";
elif [ -x /usr/bin/awk ]; then
  echo awk is `/usr/bin/awk --version | head -n1`
else 
  echo "awk not found" 
fi

gcc --version | head -n1
g++ --version | head -n1
ldd --version | head -n1 | cut -d" " -f2-  # glibc version
grep --version | head -n1
gzip --version | head -n1
cat /proc/version
m4 --version | head -n1
make --version | head -n1
patch --version | head -n1
echo Perl `perl -V:version`
sed --version | head -n1
tar --version | head -n1
makeinfo --version | head -n1
xz --version | head -n1

echo 'int main(){}' > dummy.c && g++ -o dummy dummy.c
if [ -x dummy ]
  then echo "g++ compilation OK";
  else echo "g++ compilation failed"; fi
rm -f dummy.c dummy
EOF

bash version-check.sh

rm /bin/sh
ln -s /bin/bash /bin/sh
apt-get --yes install bison
apt-get --yes install gawk
apt-get --yes install texinfo


mkdir -v $LFS/sources
chmod -v a+wt $LFS/sources
wget --input-file=packages_urls.txt --continue --directory-prefix=$LFS/sources

mkdir -v $LFS/tools
ln -sv $LFS/tools /

groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
passwd lfs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources
su - lfs

cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF

source ~/.bash_profile

cd $LFS/sources

tar -xf binutils-2.29.tar.bz2
cd binutils-2.29
mkdir -v build
cd build
../configure --prefix=/tools            \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror
make
case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac
make install
cd $LFS/sources
rm -Rf binutils-2.29

tar -xf gcc-7.2.0.tar.xz
cd gcc-7.2.0
tar -xf ../mpfr-3.1.5.tar.xz
mv -v mpfr-3.1.5 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.0.3.tar.gz
mv -v mpc-1.0.3 mpc

for file in gcc/config/{linux,i386/linux{,64}}.h
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

mkdir -v build
cd       build
../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libmpx                               \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
make
make install

cd $LFS/sources
rm -Rf gcc-7.2.0

tar -xf linux-4.12.7.tar.xz
cd linux-4.12.7
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd $LFS/sources
rm -Rf linux-4.12.7


tar -xf glibc-2.26.tar.xz
cd glibc-2.26
mkdir -v build
cd       build
../configure                             \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2             \
      --with-headers=/tools/include      \
      libc_cv_forced_unwind=yes          \
      libc_cv_c_cleanup=yes
make
make install

echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
readelf -l a.out | grep ': /tools'
rm -v dummy.c a.out

cd $LFS/sources
rm -Rf glibc-2.26


tar -xf gcc-7.2.0.tar.xz
cd gcc-7.2.0
mkdir -v build
cd       build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/7.2.0
make
make install
cd $LFS/sources
rm -Rf gcc-7.2.0


tar -xf binutils-2.29.tar.bz2
cd binutils-2.29
mkdir -v build
cd build
CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot
make
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd $LFS/sources
rm -Rf binutils-2.29

tar -xf gcc-7.2.0.tar.xz
cd gcc-7.2.0
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
for file in gcc/config/{linux,i386/linux{,64}}.h
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
tar -xf ../mpfr-3.1.5.tar.xz
mv -v mpfr-3.1.5 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.0.3.tar.gz
mv -v mpc-1.0.3 mpc
mkdir -v build
cd       build
CC=$LFS_TGT-gcc                                    \
CXX=$LFS_TGT-g++                                   \
AR=$LFS_TGT-ar                                     \
RANLIB=$LFS_TGT-ranlib                             \
../configure                                       \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp
make
make install
ln -sv gcc /tools/bin/cc
echo 'int main(){}' > dummy.c
cc dummy.c
readelf -l a.out | grep ': /tools'
rm -v dummy.c a.out

cd $LFS/sources
rm -Rf gcc-7.2.0

tar -xf tcl-core8.6.7-src.tar.gz
cd tcl8.6.7
cd unix
./configure --prefix=/tools
make
TZ=UTC make test
make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh
cd $LFS/sources
rm -Rf tcl8.6.7

tar -xf expect5.45.tar.gz
cd expect5.45
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include
make
make test
make SCRIPTS="" install
cd $LFS/sources
rm -Rf expect5.45

tar -xf dejagnu-1.6.tar.gz
cd dejagnu-1.6
./configure --prefix=/tools
make install
make check
cd $LFS/sources
rm -Rf dejagnu-1.6

tar -xf check-0.11.0.tar.gz
cd check-0.11.0
PKG_CONFIG= ./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf check-0.11.0

tar -xf ncurses-6.0.tar.gz
cd ncurses-6.0
sed -i s/mawk// configure
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
make
make install
cd $LFS/sources
rm -Rf ncurses-6.0


tar -xf bash-4.4.tar.gz
cd bash-4.4
./configure --prefix=/tools --without-bash-malloc
make
make tests
make install
ln -sv bash /tools/bin/sh
cd $LFS/sources
rm -Rf bash-4.4

tar -xf bison-3.0.4.tar.xz
cd bison-3.0.4
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf bison-3.0.4

tar -xf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
make
make PREFIX=/tools install
cd $LFS/sources
rm -Rf bzip2-1.0.6

tar -xf coreutils-8.27.tar.xz
cd coreutils-8.27
./configure --prefix=/tools --enable-install-program=hostname
make
make RUN_EXPENSIVE_TESTS=yes check
make install
cd $LFS/sources
rm -Rf coreutils-8.27

tar -xf diffutils-3.6.tar.xz
cd diffutils-3.6
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf diffutils-3.6

tar -xf file-5.31.tar.gz
cd file-5.31
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf file-5.31

tar -xf findutils-4.6.0.tar.gz
cd findutils-4.6.0
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf findutils-4.6.0

tar -xf gawk-4.1.4.tar.xz
cd gawk-4.1.4
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf gawk-4.1.4

tar -xf gettext-0.19.8.1.tar.xz
cd gettext-0.19.8.1
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext
cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
cd $LFS/sources
rm -Rf gettext-0.19.8.1

tar -xf grep-3.1.tar.xz
cd grep-3.1
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf grep-3.1

tar -xf gzip-1.8.tar.xz
cd gzip-1.8
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf gzip-1.8

tar -xf m4-1.4.18.tar.xz
cd m4-1.4.18
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf m4-1.4.18

tar -xf make-4.2.1.tar.bz2
cd make-4.2.1
./configure --prefix=/tools --without-guile
make
make check
make install
cd $LFS/sources
rm -Rf make-4.2.1

tar -xf patch-2.7.5.tar.xz
cd patch-2.7.5
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf patch-2.7.5

tar -xf perl-5.26.0.tar.xz
cd perl-5.26.0
sed -e '9751 a#ifndef PERL_IN_XSUB_RE' \
    -e '9808 a#endif'                  \
    -i regexec.c
sh Configure -des -Dprefix=/tools -Dlibs=-lm
make
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.26.0
cp -Rv lib/* /tools/lib/perl5/5.26.0
cd $LFS/sources
rm -Rf perl-5.26.0

tar -xf sed-4.4.tar.xz
cd sed-4.4
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf sed-4.4

tar -xf tar-1.29.tar.xz
cd tar-1.29
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf tar-1.29

tar -xf texinfo-6.4.tar.xz
cd texinfo-6.4
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf texinfo-6.4

tar -xf util-linux-2.30.1.tar.xz
cd util-linux-2.30.1
./configure --prefix=/tools                \
            --without-python               \
            --disable-makeinstall-chown    \
            --without-systemdsystemunitdir \
            --without-ncurses              \
            PKG_CONFIG=""
make
make install
cd $LFS/sources
rm -Rf util-linux-2.30.1

tar -xf xz-5.2.3.tar.xz
cd xz-5.2.3
./configure --prefix=/tools
make
make check
make install
cd $LFS/sources
rm -Rf xz-5.2.3

chown -R root:root $LFS/tools
mkdir -pv $LFS/{dev,proc,sys,run}
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
mount -v --bind /dev $LFS/dev

mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
    mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi


