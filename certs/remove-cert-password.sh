
# generate passwordless keyfile for certificate

if [ $# -ne 2 ]; then
  echo "usage: $0 certificate-keyfile certificate-keyfile-nopassword"
  exit 1
fi

if [ ! -r $1 ]; then
  echo "cannot open $1"
  exit 1
fi

if [ -r $2 ]; then 
  echo "output file $2 already exists"
  exit 1
fi

openssl rsa -in $1 -out $2
