FROM containers.intersystems.com/intersystems/iris-community:latest-cd

COPY --chown=irisowner:irisowner iris.script /tmp/iris.script
COPY --chown=irisowner:irisowner after.sh /tmp/after.sh
COPY --chown=irisowner:irisowner src/ /tmp/src/

RUN sed -i 's/\r$//' /tmp/after.sh
RUN chmod +x /tmp/after.sh
