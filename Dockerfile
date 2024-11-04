FROM kestra/kestra:latest

USER root
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends jq

COPY --chown=kestra:kestra upload-and-run.sh .
COPY --chown=kestra:kestra run.sh .

USER kestra
ENTRYPOINT ["./run.sh"]

CMD ["company.team", "myflow"]