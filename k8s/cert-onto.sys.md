# Install mkcert (no root required for usage)
brew install mkcert

# Install CA (one-time setup)
mkcert -install

# Generate wildcard certificate
mkcert "*.onto.one" onto.one

