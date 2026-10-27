
cd build/CoreScope || exit 1

make build-server build-ingestor
ls -l dist/corescope-server dist/corescope-ingestor
./dist/corescope-server -h 2>&1 | grep -E -- '-(config-dir|db|public|port)'
