#@NAME=all-in-one-client
#@OSS_ARTIFACT=true
FROM turbinelabs/envtemplate:0.18.0
FROM node:8.4.0
COPY --from=0 /usr/local/bin/envtemplate /usr/local/bin/envtemplate
EXPOSE 8080
RUN npm install http-server -g
COPY create-workers.js .
COPY index.html .
COPY start.sh .
RUN chmod +x start.sh
CMD ./start.sh
