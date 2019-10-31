As a db use monodb
Need to install and start mongod service
```
sudo service mongod start
```
How to install libs which neccesery to work
```
sudo apt install clang-7
sudo apt install libclang-7-dev
sudo apt-get install libprocps-dev
```

install deps
```
apt install -y crystal libclang-7-dev clang-7 libssl-dev libxml2-dev libyaml-dev libgmp-dev libreadline-dev libz-dev libclang-7-dev libprocps-dev git wget curl build-essential cmake git libgmp3-dev libprocps-dev libboost-all-dev libssl-dev libsodium-dev
```
add custom lib
```
cd docker/
cp bin/libclang.so.gz /tmp/libclang.so
sudo cp /tmp/libclang.so /usr/lib/x86_64-linux-gnu/libclang-7.so.1
sudo cp /tmp/libclang.so /usr/lib/libclang.so.7
cd ..
```
install snark
```
cd lib/libsnarc && mkdir build && cd build && cmake .. && make
```
install isekai
```
shards install
make
```
How to generate proof and verify it
```
clang-7 -DISEKAI_C_PARSER=0 -O0 -c -emit-llvm test.c
./isekai --arith=test.arith test.bc
./isekai --r1cs=test.j1 test.c --scheme=bctv14a 
./isekai --prove=testprove test.j1 --scheme=bctv14a
./isekai --verif=testprove test.j1.in --scheme=bctv14a 
```
 
python3 snarkscript.py ---- make block of transactions this is the main script
test_db_script.py ---- scropt that work with mongodb

