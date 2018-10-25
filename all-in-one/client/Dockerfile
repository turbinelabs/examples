#@NAME=all-in-one-client
FROM turbinelabs/envtemplate:0.19.0

FROM node:10

COPY --from=0 /usr/local/bin/envtemplate /usr/local/bin/envtemplate

RUN npm install http-server -g

ADD create-workers.js .
ADD index.html .
ADD start.sh .

RUN chmod +x start.sh

EXPOSE 8080

CMD ./start.sh
