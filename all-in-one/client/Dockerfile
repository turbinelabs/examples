#@NAME=all-in-one-client
FROM turbinelabs/envtemplate:0.18.2

FROM node:8.4.0

COPY --from=0 /usr/local/bin/envtemplate /usr/local/bin/envtemplate

RUN npm install http-server -g

ADD create-workers.js .
ADD index.html .
ADD start.sh .

RUN chmod +x start.sh

EXPOSE 8080

CMD ./start.sh
