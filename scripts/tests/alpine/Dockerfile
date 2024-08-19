FROM alpine

RUN apk update && apk add curl

# Install dependencies
COPY ./install.sh .

RUN chmod +x install.sh && ./install.sh

RUN ls $HOME/.local/bin/wazuh-cert-oauth2-client