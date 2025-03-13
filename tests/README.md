# Load Tests

```bash
START=1
END=5 # Adjust this to the number of agents you want to test

for i in $(seq $START $END); do docker run -d -v ./install-docker.sh:/install-docker.sh --name wazuh-test-$i ubuntu /bin/sh -c "tail -f /dev/null"; done
sleep .1
for i in $(seq $START $END); do docker exec -it wazuh-test-$i /bin/bash /install-docker.sh; done
sleep 2m
for i in $(seq $START $END); do docker exec -it wazuh-test-$i sudo /var/ossec/bin/wazuh-cert-oauth2-client o-auth2 -e https://cert.dev.wazuh.adorsys.team/api/register-agent; done
sleep .1
for i in $(seq $START $END); do docker exec -it wazuh-test-$i /bin/sh -c "curl -SL -s https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-yara/main/scripts/install.sh | bash"; done
```


to delete them all,:
```bash
for i in $(seq $START $END); do docker stop wazuh-test-$i; done
for i in $(seq $START $END); do docker rm wazuh-test-$i; done
```