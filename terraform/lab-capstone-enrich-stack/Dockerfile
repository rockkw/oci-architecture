# Only needed when building without the fn CLI (`fn build` generates an
# equivalent Dockerfile from func.yaml). Mirrors fn's two-stage python build.
# Build for the Functions shape set in main.tf (GENERIC_X86):
#   docker build --platform linux/amd64 -t capstone-enrich:0.0.1 .
FROM fnproject/python:3.11-dev AS build-stage
WORKDIR /function
ADD requirements.txt /function/
RUN pip3 install --target /python/ --no-cache --no-cache-dir -r requirements.txt && \
    rm -fr ~/.cache/pip /tmp* requirements.txt func.yaml Dockerfile .venv && \
    chmod -R o+r /python
ADD func.py /function/
RUN rm -fr /function/.pip_cache

FROM fnproject/python:3.11
WORKDIR /function
COPY --from=build-stage /python /python
COPY --from=build-stage /function /function
RUN chmod -R o+r /function
ENV PYTHONPATH=/function:/python
ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
